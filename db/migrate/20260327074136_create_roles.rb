class CreateRoles < ActiveRecord::Migration[8.1]
  def change
    create_table :roles do |t|
      t.string :title, null: false
      t.text :description
      t.text :job_spec
      t.references :company, null: false, foreign_key: true
      t.references :parent, null: true, foreign_key: { to_table: :roles }
      t.references :agent, null: true, foreign_key: false  # No agents table yet; FK added in Phase 4

      t.timestamps
    end

    add_index :roles, [ :company_id, :title ], unique: true
  end
end
