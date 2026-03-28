class CreateTaskDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :task_documents do |t|
      t.references :task, null: false, foreign_key: true
      t.references :document, null: false, foreign_key: true

      t.timestamps
    end

    add_index :task_documents, [:task_id, :document_id], unique: true
  end
end
