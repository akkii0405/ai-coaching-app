class ReflectionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_reflection, only: %i[ show edit update destroy confirm ]

  # GET /reflections or /reflections.json
  def index
    @reflections = current_user.reflections
  end

  # GET /reflections/1 or /reflections/1.json
  def show
  end

  # GET /reflections/new
  def new
    @reflection = Reflection.new(date: Date.current)
  end

  # GET /reflections/1/edit
  def edit
  end

  # POST /reflections or /reflections.json
  def create
    @reflection = Reflection.new(reflection_params)
    @reflection.user_id = current_user.id
    @reflection.status = :draft # 最初は必ず「下書き状態」としてスタート

    generate_ai_proposal

    respond_to do |format|
      if @reflection.save
        format.html { redirect_to @reflection, notice: "AIが明日の予定を提案しました！" }
      else
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /reflections/1 or /reflections/1.json
  def update
    # assign_attributes は、まだ保存はせずに、ユーザーの新しい入力内容で「上書き準備」をするメソッドです
    @reflection.assign_attributes(reflection_params)

    # 新しい要望が入った状態で、もう一度AIに提案を作り直させる！
    generate_ai_proposal

    respond_to do |format|
      if @reflection.save
        format.html { redirect_to @reflection, notice: "AIが提案を再構築しました！" }
      else
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /reflections/1 or /reflections/1.json
  def destroy
    @reflection.destroy!

    respond_to do |format|
      format.html { redirect_to reflections_path, notice: "Reflection was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  def confirm
    # 【追加】鉄壁のガード：もしすでに確定済み（confirmed）なら、ここで処理を強制終了して一覧画面に追い返す！
    if @reflection.confirmed?
      redirect_to tasks_path, alert: "すでにカレンダーに登録済みのデータです。"
      return # ← これ以上下のコード（保存処理）を実行させないための魔法の言葉
    end

    # 1. 明日の日付を準備する
    tomorrow = Date.tomorrow

    # 2. AIが提案したタスクリストを1つずつ取り出し、本物のTaskとして保存！
    @reflection.ai_suggested_tasks.each do |task_data|
      # ※ もしTaskテーブルに日付を入れるカラム（start_timeやdateなど）があれば追加してください
      current_user.tasks.create!(
        title: task_data["title"]
      )
    end

    # 3. この振り返りデータの状態を「確定済み(confirmed)」に更新する
    @reflection.update(status: :confirmed)

    # 4. 保存が終わったら、タスク一覧（カレンダー）画面へ移動する
    redirect_to tasks_path, notice: "AIの提案をカレンダーに登録しました！"
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_reflection
      @reflection = Reflection.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def reflection_params
      params.expect(reflection: [ :date, :task_volume, :comment, :ai_feedback, :ai_suggested_tasks, :status, :user_id ])
    end

    private
    # (既存の set_reflection や reflection_params はそのまま残します)

    # 【追加】AIに提案を作らせる共通メソッド（必殺技）
    def generate_ai_proposal
      volume_jp = { "too_much" => "多い", "just_right" => "ちょうどいい", "too_little" => "少ない" }
      current_volume = volume_jp[@reflection.task_volume]

      # --- 1. 目標とロードマップの取得 ---
      goals_info = current_user.goals.map do |g|
        "・目標: #{g.title}\n  ロードマップ: #{g.ai_roadmap}"
      end.join("\n\n")
      goals_info = "設定なし" if goals_info.blank?

      # --- 2. 今日のタスクとその状態を取得 ---
      # ※ taskテーブルに「due_date（期日）」カラムがある前提のコードです
      todays_tasks = current_user.tasks.where(due_date: @reflection.date).map do |task|
        
        # モデルで定義しているenum（status）の値に合わせて日本語に変換します
        # （例: "completed" や "done" なら完了とする）
        status_jp = if task.status == "completed" 
                      "完了"
                    else
                      "未完了"
                    end
        
        "・#{task.title} 【#{status_jp}】"
      end.join("\n")
      
      todays_tasks = "今日のタスクは設定されていませんでした。" if todays_tasks.blank?

      # --- 3. 過去の振り返りの取得（直近3件） ---
      # id: nil を除外することで、今まさに保存しようとしている未確定のデータを除きます
      past_reflections = current_user.reflections.where.not(id: nil).order(date: :desc).limit(3).map do |r|
        "・#{r.date}: #{r.comment}"
      end.join("\n")
      past_reflections = "なし" if past_reflections.blank?

      client = OpenAI::Client.new
      prompt = <<~PROMPT
        あなたはプロのAIコーチです。ユーザーの長期的な目標、過去のタスク履歴、過去の振り返り、そして今日の要望をもとに、最適なフィードバックと明日のタスク案を作成してください。
        必ず以下のJSONフォーマットのみで出力してください。

        【ユーザーの長期目標とロードマップ】
        #{goals_info}

        【今日のタスク一覧と結果】
        #{todays_tasks}

        【過去の振り返り（直近3件）】
        #{past_reflections}

        【今日の振り返り（最新）】
        今日のタスク量: #{current_volume}
        原因や要望: #{@reflection.comment}

        【出力形式 (JSON)】
        {
          "ai_feedback": "ユーザーへのフィードバックや応援メッセージ（150文字程度）",
          "suggested_tasks": [
            {
              "title": "タスク名（具体的に）",
              "task_type": "must_do または bonus"
            }
          ]
        }
      PROMPT

      begin
        response = client.chat(
          parameters: {
            model: "gpt-4o-mini",
            response_format: { type: "json_object" },
            messages: [{ role: "user", content: prompt }]
          }
        )
        result = JSON.parse(response.dig("choices", 0, "message", "content"))
        @reflection.ai_feedback = result["ai_feedback"]
        @reflection.ai_suggested_tasks = result["suggested_tasks"]
      rescue => e
        Rails.logger.error("AI通信エラー (ReflectionsController): #{e.class}: #{e.message}")
        Rails.logger.error(e.backtrace&.first(10)&.join("\n"))
        @reflection.ai_feedback = "AIの提案生成に失敗しました。"
        @reflection.ai_suggested_tasks = []
      end
    end
end
