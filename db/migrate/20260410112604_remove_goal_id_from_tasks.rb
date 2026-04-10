class RemoveGoalIdFromTasks < ActiveRecord::Migration[8.1]
  def up
    remove_foreign_key :tasks, :goals
    remove_index :tasks, :goal_id if index_exists?(:tasks, :goal_id)
    remove_column :tasks, :goal_id
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
