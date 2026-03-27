class CreateApprovalGates < ActiveRecord::Migration[8.1]
  def change
    create_table :approval_gates do |t|
      t.references :agent, null: false, foreign_key: true
      t.string :action_type, null: false
      t.boolean :enabled, default: true, null: false
      t.timestamps
    end

    add_index :approval_gates, [ :agent_id, :action_type ], unique: true,
              name: "index_approval_gates_on_agent_and_action_type"
  end
end
