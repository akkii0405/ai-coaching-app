class Reflection < ApplicationRecord
  belongs_to :user
  
  # タスク量の3択（0: 多い, 1: ちょうどいい, 2: 少ない）
  enum :task_volume, { too_much: 0, just_right: 1, too_little: 2 }

  # 提案の状態（0: 提案中/下書き, 1: 確定済み）
  enum :status, { draft: 0, confirmed: 1 }
end
