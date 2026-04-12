class CreateTaskEvaluations < ActiveRecord::Migration[8.1]
  def change
    create_table :task_evaluations do |t|
      t.references :project, null: false, foreign_key: true
      t.references :task, null: false, foreign_key: true
      t.references :root_task, null: false, foreign_key: { to_table: :tasks }
      t.references :role, null: false, foreign_key: true
      t.integer :result, null: false
      t.text :feedback, null: false
      t.integer :attempt_number, null: false
      t.integer :cost_cents

      t.timestamps
    end

    add_index :task_evaluations, [ :task_id, :attempt_number ], unique: true
  end
end
