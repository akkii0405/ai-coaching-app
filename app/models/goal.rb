class Goal < ApplicationRecord
  belongs_to :user

  # 【追加】AIが作るロードマップ(JSONデータ)を安全に扱うための魔法
  serialize :ai_roadmap, coder: JSON

  enum :status, { in_progress: 0, completed: 1, draft: 2 }
  validates :title, presence: true
  validates :target_date, presence: true
  validate :goals_count_limit, on: :create

  private

  def goals_count_limit
    # 「自分の目標の中で、進行中(in_progress)のものが3つ以上あるか」を数える
    if user && user.goals.where(status: :in_progress).count >= 3
      errors.add(:base, "設定できる進行中の目標は3つまでです！まずは今の目標に集中しましょう。")
    end
  end
end
