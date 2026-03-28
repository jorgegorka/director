class CreateGoalEvaluations < ActiveRecord::Migration[8.0]
  def change
    create_table :goal_evaluations do |t|
      t.references :company, null: false, foreign_key: true
      t.references :task, null: false, foreign_key: true
      t.references :goal, null: false, foreign_key: true
      t.references :agent, null: false, foreign_key: true
      t.integer :result, null: false
      t.text :feedback, null: false
      t.integer :attempt_number, null: false
      t.integer :cost_cents

      t.timestamps
    end

    add_index :goal_evaluations, [ :task_id, :attempt_number ], unique: true
  end
end
