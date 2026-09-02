json.extract! task, :id, :title, :due_date, :task_type, :status, :created_at, :updated_at
json.url task_url(task, format: :json)
