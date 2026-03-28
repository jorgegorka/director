class CreateDocumentTags < ActiveRecord::Migration[8.1]
  def change
    create_table :document_tags do |t|
      t.references :company, null: false, foreign_key: true
      t.string :name, null: false

      t.timestamps
    end

    add_index :document_tags, [ :company_id, :name ], unique: true
  end
end
