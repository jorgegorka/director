class AddCompanyIdToAuditEvents < ActiveRecord::Migration[8.1]
  def change
    add_reference :audit_events, :company, foreign_key: true

    # Backfill: set company_id from the auditable's company_id (tasks have company_id)
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE audit_events
          SET company_id = tasks.company_id
          FROM tasks
          WHERE audit_events.auditable_type = 'Task'
            AND audit_events.auditable_id = tasks.id
            AND audit_events.company_id IS NULL
        SQL
      end
    end

    add_index :audit_events, [ :company_id, :created_at ], name: "index_audit_events_on_company_and_time"
    add_index :audit_events, [ :company_id, :action ], name: "index_audit_events_on_company_and_action"
  end
end
