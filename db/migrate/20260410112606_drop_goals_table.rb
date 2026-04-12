class DropGoalsTable < ActiveRecord::Migration[8.1]
  def up
    execute "DELETE FROM audit_events WHERE auditable_type = 'Goal'"
    drop_table :goals
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
