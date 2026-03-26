class CreateInvitations < ActiveRecord::Migration[8.1]
  def change
    create_table :invitations do |t|
      t.references :company, null: false, foreign_key: true
      t.references :inviter, null: false, foreign_key: { to_table: :users }
      t.string :email_address, null: false
      t.integer :role, default: 0, null: false
      t.string :token, null: false
      t.integer :status, default: 0, null: false
      t.datetime :accepted_at
      t.datetime :expires_at, null: false

      t.timestamps
    end

    add_index :invitations, :token, unique: true
    add_index :invitations, [ :company_id, :email_address ], unique: true, where: "status = 0", name: "index_invitations_on_company_and_email_pending"
  end
end
