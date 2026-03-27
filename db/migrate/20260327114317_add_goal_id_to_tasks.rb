class AddGoalIdToTasks < ActiveRecord::Migration[8.1]
  def change
    add_reference :tasks, :goal, foreign_key: true
  end
end
