class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :notifications do |t|
      t.references :company, null: false, foreign_key: true
      t.references :recipient, polymorphic: true, null: false, index: false  # User who receives notification
      t.references :actor, polymorphic: true, index: false                    # Who/what caused it (Agent, User, system)
      t.references :notifiable, polymorphic: true, index: false               # The related object (Agent for budget alerts)
      t.string :action, null: false                                           # e.g. "budget_alert", "budget_exhausted"
      t.json :metadata, default: {}, null: false                             # extra context (percentage, amounts, etc.)
      t.datetime :read_at                                                     # nil = unread
      t.timestamps
    end

    add_index :notifications, [ :recipient_type, :recipient_id, :read_at ], name: "index_notifications_on_recipient_and_read"
    add_index :notifications, [ :notifiable_type, :notifiable_id ], name: "index_notifications_on_notifiable"
    add_index :notifications, [ :company_id, :created_at ], name: "index_notifications_on_company_and_time"
  end
end
