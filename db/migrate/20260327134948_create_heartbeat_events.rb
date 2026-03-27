class CreateHeartbeatEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :heartbeat_events do |t|
      t.references :agent, null: false, foreign_key: true
      t.integer :trigger_type, null: false, default: 0  # enum: scheduled, task_assigned, mention
      t.string :trigger_source                           # e.g. "Task#42", "Message#15", "schedule"
      t.integer :status, null: false, default: 0        # enum: queued, delivered, failed
      t.datetime :delivered_at
      t.jsonb :request_payload, default: {}, null: false  # what was sent to the agent
      t.jsonb :response_payload, default: {}, null: false # what came back (for HTTP agents)
      t.jsonb :metadata, default: {}, null: false          # extra context (error messages, etc.)
      t.timestamps
    end
    add_index :heartbeat_events, [ :agent_id, :created_at ], name: "index_heartbeat_events_on_agent_and_time"
    add_index :heartbeat_events, [ :agent_id, :trigger_type ], name: "index_heartbeat_events_on_agent_and_trigger"
    add_index :heartbeat_events, :status
  end
end
