class CreateHookExecutions < ActiveRecord::Migration[8.1]
  def change
    create_table :hook_executions do |t|
      t.references :agent_hook, null: false, foreign_key: true, index: false
      t.references :task, null: false, foreign_key: true, index: false
      t.references :company, null: false, foreign_key: true, index: false
      t.integer :status, null: false, default: 0
      t.json :input_payload, null: false, default: {}
      t.json :output_payload, null: false, default: {}
      t.text :error_message
      t.datetime :started_at
      t.datetime :completed_at
      t.timestamps
    end

    add_index :hook_executions, [ :task_id, :created_at ]
    add_index :hook_executions, [ :agent_hook_id, :status ]
    add_index :hook_executions, [ :company_id ]
  end
end
