class CreateReflections < ActiveRecord::Migration[8.1]
  def change
    create_table :reflections do |t|
      t.date :date
      t.integer :task_volume
      t.text :comment
      t.text :ai_feedback
      t.json :ai_suggested_tasks
      t.integer :status
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
