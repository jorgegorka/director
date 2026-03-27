class CreateGoals < ActiveRecord::Migration[8.1]
  def change
    create_table :goals do |t|
      t.references :company, null: false, foreign_key: true
      t.references :parent, foreign_key: { to_table: :goals }
      t.string :title, null: false
      t.text :description
      t.integer :position, default: 0, null: false

      t.timestamps
    end

    add_index :goals, [ :company_id, :parent_id ]
  end
end
