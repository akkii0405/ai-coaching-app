class CreateGoals < ActiveRecord::Migration[8.1]
  def change
    create_table :goals do |t|
      t.string :title
      t.text :ai_roadmap
      t.integer :status
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
