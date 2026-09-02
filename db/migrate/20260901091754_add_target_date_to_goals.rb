class AddTargetDateToGoals < ActiveRecord::Migration[8.1]
  def change
    add_column :goals, :target_date, :date
  end
end
