class CreateAgentHooks < ActiveRecord::Migration[8.1]
  def change
    create_table :agent_hooks do |t|
      t.references :agent, null: false, foreign_key: true
      t.references :company, null: false, foreign_key: true, index: false
      t.string :lifecycle_event, null: false
      t.integer :action_type, null: false, default: 0
      t.json :action_config, null: false, default: {}
      t.boolean :enabled, null: false, default: true
      t.integer :position, null: false, default: 0
      t.string :name
      t.json :conditions, null: false, default: {}
      t.timestamps
    end

    add_index :agent_hooks, [ :agent_id, :lifecycle_event ]
    add_index :agent_hooks, [ :agent_id, :enabled ]
    add_index :agent_hooks, [ :company_id ]
  end
end
