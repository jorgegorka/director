class CreateDocumentTaggings < ActiveRecord::Migration[8.1]
  def change
    create_table :document_taggings do |t|
      t.references :document, null: false, foreign_key: true
      t.references :document_tag, null: false, foreign_key: true

      t.timestamps
    end

    add_index :document_taggings, [ :document_id, :document_tag_id ], unique: true
  end
end
