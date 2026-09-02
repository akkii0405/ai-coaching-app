class GoalsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_goal, only: %i[ show edit update destroy confirm ]

  # GET /goals or /goals.json
  def index
    @goals = current_user.goals
  end

  # GET /goals/1 or /goals/1.json
  def show
  end

  # GET /goals/new
  def new
    @goal = Goal.new
  end

  # GET /goals/1/edit
  def edit
  end

  # POST /goals or /goals.json
  def create
    @goal = Goal.new(goal_params)
    @goal.user_id = current_user.id
    @goal.status = :draft # 最初は必ず「下書き状態」としてスタート

    generate_ai_roadmap # 【AI通信】ロードマップを生成するメソッドを呼び出す

    respond_to do |format|
      if @goal.save
        format.html { redirect_to @goal, notice: "AIがロードマップを作成しました！内容を確認してください。" }
      else
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /goals/1 or /goals/1.json
  def update
    @goal.assign_attributes(goal_params)

    # ユーザーからの「追加要望(params[:ai_request])」を含めてAIに再提案させる！
    generate_ai_roadmap

    respond_to do |format|
      if @goal.save
        format.html { redirect_to @goal, notice: "AIがロードマップを再構築しました！" }
      else
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /goals/1 or /goals/1.json
  def destroy
    @goal.destroy!

    respond_to do |format|
      format.html { redirect_to goals_path, notice: "Goal was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  def confirm
    # もしすでに進行中ならブロック
    if @goal.in_progress?
      redirect_to goals_path, alert: "すでに進行中の目標です。"
      return
    end

    # 【重要】進行中の目標がすでに3つあるかチェックする！
    if current_user.goals.where(status: :in_progress).count >= 3
      redirect_to @goal, alert: "設定できる進行中の目標は3つまでです！まずは今の目標に集中しましょう。"
      return
    end

    # ステータスを in_progress（進行中）に更新！
    @goal.update(status: :in_progress)

    # 完了したら目標一覧画面へ
    redirect_to goals_path, notice: "目標を確定しました！今日から頑張りましょう！"
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_goal
      # 「全員の目標」からではなく、「今ログインしているユーザーの目標」の中から探す！
      @goal = current_user.goals.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def goal_params
      # ユーザーが画面から送信していいのは、title と target_date だけ！
      params.expect(goal: [ :title, :target_date ])
    end

    def generate_ai_roadmap
      client = OpenAI::Client.new
      
      # AIが期間を計算しやすいように、今日の日付も教えてあげる
      today = Date.current

      # params[:ai_request] は、後で「やり直し」の時にユーザーの要望を受け取るための隠し味です
      request_text = params[:ai_request].present? ? params[:ai_request] : "特になし"

      prompt = <<~PROMPT
        あなたはプロのAIコーチです。ユーザーの目標と達成期限をもとに、実現可能なロードマップ（ステップごとの計画）を作成してください。
        必ず以下のJSONフォーマットのみで出力してください。

        【ユーザーの目標情報】
        目標: #{@goal.title}
        達成期限: #{@goal.target_date} (今日の日付は #{today} です)
        追加の要望: #{request_text}

        【出力形式 (JSON)】
        {
          "ai_message": "この目標に対するAIコーチからの応援メッセージや戦略アドバイス（150文字程度）",
          "roadmap": [
            {
              "step": 1,
              "period": "〇月〇日 〜 〇月〇日 (または最初の1週間など)",
              "milestone": "達成すべき状態・マイルストーン",
              "focus_points": ["意識すること1", "意識すること2"]
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
        # JSONをRubyのハッシュに変換して、そのまま ai_roadmap カラムに保存する！
        @goal.ai_roadmap = JSON.parse(response.dig("choices", 0, "message", "content"))
      rescue => e
        puts "AI通信エラー: #{e.message}"
        @goal.ai_roadmap = { "ai_message" => "ロードマップの生成に失敗しました。", "roadmap" => [] }
      end
    end
end
