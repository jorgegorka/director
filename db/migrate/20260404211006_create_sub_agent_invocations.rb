class CreateSubAgentInvocations < ActiveRecord::Migration[8.1]
  def change
    create_table :sub_agent_invocations do |t|
      t.references :role_run, null: false, foreign_key: true
      t.references :company, null: false, foreign_key: true
      t.string :sub_agent_name, null: false
      t.integer :status, default: 0, null: false
      t.integer :cost_cents, default: 0, null: false
      t.integer :duration_ms
      t.integer :iterations, default: 0, null: false
      t.text :input_summary
      t.text :result_summary
      t.text :error_message

      t.timestamps
    end

    add_index :sub_agent_invocations, [ :role_run_id, :created_at ]
    add_index :sub_agent_invocations, [ :company_id, :sub_agent_name ]
  end
end
