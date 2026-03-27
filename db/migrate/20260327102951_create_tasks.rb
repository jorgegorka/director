class CreateTasks < ActiveRecord::Migration[8.1]
  def change
    create_table :tasks do |t|
      t.references :company, null: false, foreign_key: true
      t.references :creator, null: false, foreign_key: { to_table: :users }
      t.references :assignee, foreign_key: { to_table: :agents }
      t.references :parent_task, foreign_key: { to_table: :tasks }
      t.string :title, null: false
      t.text :description
      t.integer :status, null: false, default: 0
      t.integer :priority, null: false, default: 1
      t.datetime :due_at
      t.datetime :completed_at
      t.timestamps
    end

    add_index :tasks, [ :company_id, :status ]
    add_index :tasks, [ :assignee_id, :status ]
  end
end
