class AddLastActivityAtToRoleRuns < ActiveRecord::Migration[8.1]
  def change
    add_column :role_runs, :last_activity_at, :datetime
    add_index :role_runs, [ :status, :last_activity_at ]
  end
end
