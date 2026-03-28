class DropAgentCapabilities < ActiveRecord::Migration[8.1]
  def up
    drop_table :agent_capabilities
  end

  def down
    create_table :agent_capabilities do |t|
      t.references :agent, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.timestamps
    end
    add_index :agent_capabilities, [ :agent_id, :name ], unique: true
  end
end
