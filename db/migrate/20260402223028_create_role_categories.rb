class CreateRoleCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :role_categories do |t|
      t.string :name, null: false
      t.text :description
      t.text :job_spec, null: false
      t.references :company, null: false, foreign_key: true

      t.timestamps
    end

    add_index :role_categories, [ :company_id, :name ], unique: true
  end
end
