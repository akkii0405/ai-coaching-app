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

      client = OpenAI::Client.new
      prompt = <<~PROMPT
        あなたはプロのAIコーチです。ユーザーの今日の振り返りと要望をもとに、フィードバックと明日のタスク案を作成してください。
        必ず以下のJSONフォーマットのみで出力してください。

        【ユーザーの振り返り】
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
        puts "AI通信エラー: #{e.message}"
        @reflection.ai_feedback = "AIの提案生成に失敗しました。"
        @reflection.ai_suggested_tasks = []
      end
    end
end
