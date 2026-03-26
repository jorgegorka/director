class CreateMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :memberships do |t|
      t.references :company, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :role, default: 0, null: false

      t.timestamps
    end

    add_index :memberships, [ :company_id, :user_id ], unique: true
  end
end
