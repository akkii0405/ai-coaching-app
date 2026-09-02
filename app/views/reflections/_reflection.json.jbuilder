json.extract! reflection, :id, :date, :task_volume, :comment, :ai_feedback, :ai_suggested_tasks, :status, :user_id, :created_at, :updated_at
json.url reflection_url(reflection, format: :json)
