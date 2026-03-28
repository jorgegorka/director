class CreateAgentRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :agent_runs do |t|
      t.references :agent, null: false, foreign_key: true
      t.references :task, null: true, foreign_key: true
      t.references :company, null: false, foreign_key: true
      t.integer :status, null: false, default: 0
      t.text :log_output
      t.integer :exit_code
      t.integer :cost_cents
      t.string :claude_session_id
      t.string :trigger_type
      t.text :error_message
      t.datetime :started_at
      t.datetime :completed_at
      t.timestamps
    end

    add_index :agent_runs, [ :agent_id, :status ]
    add_index :agent_runs, [ :agent_id, :created_at ]
    add_index :agent_runs, [ :company_id, :created_at ]
    add_index :agent_runs, :claude_session_id
  end
end
