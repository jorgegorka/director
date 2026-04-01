class AddGoalIdToRoleRunsAndCompletionPercentageToTasks < ActiveRecord::Migration[8.1]
  def change
    add_column :role_runs, :goal_id, :integer
    add_index :role_runs, :goal_id

    add_column :tasks, :completion_percentage, :integer, default: 0, null: false
  end
end
