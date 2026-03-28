class CreateAuditEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_events do |t|
      t.references :auditable, polymorphic: true, null: false
      t.references :actor, polymorphic: true, null: false
      t.string :action, null: false
      t.json :metadata, null: false, default: {}
      t.datetime :created_at, null: false
    end

    add_index :audit_events, [ :auditable_type, :auditable_id, :created_at ], name: "index_audit_events_on_auditable_and_created_at"
    add_index :audit_events, :action
  end
end
