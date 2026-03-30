class CreatePendingHires < ActiveRecord::Migration[8.1]
  def change
    create_table :pending_hires do |t|
      t.references :role, null: false, foreign_key: true
      t.references :company, null: false, foreign_key: true
      t.string :template_role_title, null: false
      t.integer :budget_cents, null: false
      t.integer :status, default: 0, null: false
      t.references :resolved_by, foreign_key: { to_table: :users }
      t.datetime :resolved_at
      t.timestamps
    end

    add_index :pending_hires, [ :company_id, :status ]
  end
end
