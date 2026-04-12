class DropGoalEvaluations < ActiveRecord::Migration[8.1]
  def up
    drop_table :goal_evaluations
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
