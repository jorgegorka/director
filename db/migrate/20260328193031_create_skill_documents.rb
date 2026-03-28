class CreateSkillDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :skill_documents do |t|
      t.references :skill, null: false, foreign_key: true
      t.references :document, null: false, foreign_key: true

      t.timestamps
    end

    add_index :skill_documents, [ :skill_id, :document_id ], unique: true
  end
end
