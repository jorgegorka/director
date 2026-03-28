class CreateDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :documents do |t|
      t.references :company, null: false, foreign_key: true
      t.string :title, null: false
      t.text :body, null: false
      t.string :author_type, null: false
      t.integer :author_id, null: false
      t.string :last_editor_type
      t.integer :last_editor_id

      t.timestamps
    end

    add_index :documents, [ :author_type, :author_id ]
    add_index :documents, [ :last_editor_type, :last_editor_id ]
  end
end
