class CreateHeartbeatEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :heartbeat_events do |t|
      t.references :agent, null: false, foreign_key: true
      t.integer :trigger_type, null: false, default: 0
      t.string :trigger_source
      t.integer :status, null: false, default: 0
      t.datetime :delivered_at
      t.json :request_payload, default: {}, null: false
      t.json :response_payload, default: {}, null: false
      t.json :metadata, default: {}, null: false
      t.timestamps
    end
    add_index :heartbeat_events, [ :agent_id, :created_at ], name: "index_heartbeat_events_on_agent_and_time"
    add_index :heartbeat_events, [ :agent_id, :trigger_type ], name: "index_heartbeat_events_on_agent_and_trigger"
    add_index :heartbeat_events, :status
  end
end
