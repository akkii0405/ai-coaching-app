class CreateTasks < ActiveRecord::Migration[8.1]
  def change
    create_table :tasks do |t|
      t.string :title
      t.date :due_date
      t.integer :task_type
      t.integer :status

      t.timestamps
    end
  end
end
