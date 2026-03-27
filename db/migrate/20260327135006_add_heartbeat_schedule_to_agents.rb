class AddHeartbeatScheduleToAgents < ActiveRecord::Migration[8.1]
  def change
    add_column :agents, :heartbeat_interval, :integer    # minutes between heartbeats (nil = no schedule)
    add_column :agents, :heartbeat_enabled, :boolean, default: false, null: false
  end
end
