class RemoveGoalIdFromRoleRuns < ActiveRecord::Migration[8.1]
  def up
    remove_index :role_runs, :goal_id if index_exists?(:role_runs, :goal_id)
    remove_column :role_runs, :goal_id
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
