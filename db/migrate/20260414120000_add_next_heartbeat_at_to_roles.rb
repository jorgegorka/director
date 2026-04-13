class AddNextHeartbeatAtToRoles < ActiveRecord::Migration[8.1]
  def change
    add_column :roles, :next_heartbeat_at, :datetime
    add_index  :roles, :next_heartbeat_at
  end
end
