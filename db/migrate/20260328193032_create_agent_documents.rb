class CreateAgentDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :agent_documents do |t|
      t.references :agent, null: false, foreign_key: true
      t.references :document, null: false, foreign_key: true

      t.timestamps
    end

    add_index :agent_documents, [:agent_id, :document_id], unique: true
  end
end
