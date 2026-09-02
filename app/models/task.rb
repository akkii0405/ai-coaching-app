class Task < ApplicationRecord
  belongs_to :user

  enum :task_type, { must_do: 0, bonus: 1 }

  enum :status, { pending: 0, completed: 1 }
end
