class CreateAgents < ActiveRecord::Migration[8.1]
  def change
    create_table :agents do |t|
      t.references :company, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :adapter_type, null: false, default: 0
      t.integer :status, null: false, default: 0
      t.jsonb :adapter_config, null: false, default: {}
      t.text :description
      t.datetime :last_heartbeat_at
      t.text :pause_reason
      t.datetime :paused_at
      t.timestamps
    end

    add_index :agents, [ :company_id, :name ], unique: true
    add_index :agents, :status

    add_foreign_key :roles, :agents
  end
end
