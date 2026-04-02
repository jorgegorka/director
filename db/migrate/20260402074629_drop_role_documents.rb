class DropRoleDocuments < ActiveRecord::Migration[8.1]
  def change
    drop_table :role_documents do |t|
      t.integer :role_id, null: false
      t.integer :document_id, null: false
      t.timestamps
      t.index [ :role_id, :document_id ], unique: true
      t.index :document_id
    end
  end
end
