class RenameCompanyToProject < ActiveRecord::Migration[8.1]
  def up
    rename_table :companies, :projects

    tables_with_company_id = %i[
      audit_events config_versions document_tags documents goal_evaluations
      goals hook_executions invitations memberships notifications
      pending_hires role_categories role_hooks role_runs roles
      skills sub_agent_invocations tasks
    ]

    # rename_column on SQLite rebuilds the table, which automatically renames
    # single-column indexes (company_id → project_id). Compound indexes with
    # custom names keep their old names but point to the new column.
    tables_with_company_id.each do |table|
      rename_column table, :company_id, :project_id
    end

    # Fix compound index names that still reference "company"
    {
      "index_audit_events_on_company_and_action" => "index_audit_events_on_project_and_action",
      "index_audit_events_on_company_and_time" => "index_audit_events_on_project_and_time",
      "index_document_tags_on_company_id_and_name" => "index_document_tags_on_project_id_and_name",
      "index_invitations_on_company_and_email_pending" => "index_invitations_on_project_and_email_pending",
      "index_memberships_on_company_id_and_user_id" => "index_memberships_on_project_id_and_user_id",
      "index_notifications_on_company_and_time" => "index_notifications_on_project_and_time",
      "index_pending_hires_on_company_id_and_status" => "index_pending_hires_on_project_id_and_status",
      "index_role_categories_on_company_id_and_name" => "index_role_categories_on_project_id_and_name",
      "index_role_runs_on_company_id_and_created_at" => "index_role_runs_on_project_id_and_created_at",
      "index_roles_on_company_id_and_title" => "index_roles_on_project_id_and_title",
      "index_skills_on_company_id_and_category" => "index_skills_on_project_id_and_category",
      "index_skills_on_company_id_and_key" => "index_skills_on_project_id_and_key",
      "index_sub_agent_invocations_on_company_id_and_sub_agent_name" => "index_sub_agent_invocations_on_project_id_and_sub_agent_name",
      "index_tasks_on_company_id_and_status" => "index_tasks_on_project_id_and_status"
    }.each do |old_name, new_name|
      # Read the original CREATE INDEX statement from sqlite_master
      row = execute("SELECT sql FROM sqlite_master WHERE type='index' AND name='#{old_name}'").first
      next unless row # already renamed by rename_column

      create_sql = row["sql"].sub(old_name, new_name)
      execute "DROP INDEX \"#{old_name}\""
      execute create_sql
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
