class CreateMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :messages do |t|
      t.references :task, null: false, foreign_key: true
      t.references :author, polymorphic: true, null: false
      t.references :parent, foreign_key: { to_table: :messages }
      t.text :body, null: false
      t.timestamps
    end

    add_index :messages, [ :task_id, :created_at ]
  end
end
