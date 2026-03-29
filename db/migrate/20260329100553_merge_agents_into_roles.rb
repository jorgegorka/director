class MergeAgentsIntoRoles < ActiveRecord::Migration[8.1]
  def up
    # Step 1: Add agent columns to roles
    add_column :roles, :adapter_type, :integer
    add_column :roles, :adapter_config, :json, default: {}, null: false
    add_column :roles, :api_token, :string
    add_column :roles, :status, :integer, default: 0, null: false
    add_column :roles, :budget_cents, :integer
    add_column :roles, :budget_period_start, :date
    add_column :roles, :heartbeat_enabled, :boolean, default: false, null: false
    add_column :roles, :heartbeat_interval, :integer
    add_column :roles, :last_heartbeat_at, :datetime
    add_column :roles, :pause_reason, :text
    add_column :roles, :paused_at, :datetime

    add_index :roles, :api_token, unique: true
    add_index :roles, :status

    # Step 2: Copy data from agents into roles via agent_id FK
    execute <<~SQL
      UPDATE roles
      SET adapter_type     = agents.adapter_type,
          adapter_config   = agents.adapter_config,
          api_token        = agents.api_token,
          status           = agents.status,
          budget_cents      = agents.budget_cents,
          budget_period_start = agents.budget_period_start,
          heartbeat_enabled = agents.heartbeat_enabled,
          heartbeat_interval = agents.heartbeat_interval,
          last_heartbeat_at = agents.last_heartbeat_at,
          pause_reason      = agents.pause_reason,
          paused_at         = agents.paused_at
      FROM agents
      WHERE roles.agent_id = agents.id
    SQL

    # Step 3: Build agent_id → role_id mapping and re-point FKs
    # We need to update tables that reference agent_id to point to role_id instead
    mapping = execute("SELECT agent_id, id FROM roles WHERE agent_id IS NOT NULL")

    # Re-point tasks.assignee_id (agent_id → role_id)
    execute <<~SQL
      UPDATE tasks
      SET assignee_id = (
        SELECT roles.id FROM roles WHERE roles.agent_id = tasks.assignee_id
      )
      WHERE assignee_id IS NOT NULL
        AND assignee_id IN (SELECT agent_id FROM roles WHERE agent_id IS NOT NULL)
    SQL

    # Re-point goals.agent_id
    execute <<~SQL
      UPDATE goals
      SET agent_id = (
        SELECT roles.id FROM roles WHERE roles.agent_id = goals.agent_id
      )
      WHERE agent_id IS NOT NULL
        AND agent_id IN (SELECT agent_id FROM roles WHERE agent_id IS NOT NULL)
    SQL

    # Re-point goal_evaluations.agent_id
    execute <<~SQL
      UPDATE goal_evaluations
      SET agent_id = (
        SELECT roles.id FROM roles WHERE roles.agent_id = goal_evaluations.agent_id
      )
      WHERE agent_id IN (SELECT agent_id FROM roles WHERE agent_id IS NOT NULL)
    SQL

    # Re-point approval_gates.agent_id
    execute <<~SQL
      UPDATE approval_gates
      SET agent_id = (
        SELECT roles.id FROM roles WHERE roles.agent_id = approval_gates.agent_id
      )
      WHERE agent_id IN (SELECT agent_id FROM roles WHERE agent_id IS NOT NULL)
    SQL

    # Re-point heartbeat_events.agent_id
    execute <<~SQL
      UPDATE heartbeat_events
      SET agent_id = (
        SELECT roles.id FROM roles WHERE roles.agent_id = heartbeat_events.agent_id
      )
      WHERE agent_id IN (SELECT agent_id FROM roles WHERE agent_id IS NOT NULL)
    SQL

    # Re-point agent_documents.agent_id
    execute <<~SQL
      UPDATE agent_documents
      SET agent_id = (
        SELECT roles.id FROM roles WHERE roles.agent_id = agent_documents.agent_id
      )
      WHERE agent_id IN (SELECT agent_id FROM roles WHERE agent_id IS NOT NULL)
    SQL

    # Re-point agent_skills.agent_id
    execute <<~SQL
      UPDATE agent_skills
      SET agent_id = (
        SELECT roles.id FROM roles WHERE roles.agent_id = agent_skills.agent_id
      )
      WHERE agent_id IN (SELECT agent_id FROM roles WHERE agent_id IS NOT NULL)
    SQL

    # Re-point agent_hooks.agent_id
    execute <<~SQL
      UPDATE agent_hooks
      SET agent_id = (
        SELECT roles.id FROM roles WHERE roles.agent_id = agent_hooks.agent_id
      )
      WHERE agent_id IN (SELECT agent_id FROM roles WHERE agent_id IS NOT NULL)
    SQL

    # Re-point agent_runs.agent_id
    execute <<~SQL
      UPDATE agent_runs
      SET agent_id = (
        SELECT roles.id FROM roles WHERE roles.agent_id = agent_runs.agent_id
      )
      WHERE agent_id IN (SELECT agent_id FROM roles WHERE agent_id IS NOT NULL)
    SQL

    # Re-point hook_executions.agent_hook_id stays pointing at agent_hooks table
    # (the table is being renamed, but the IDs stay the same)

    # Update polymorphic references: Agent → Role
    execute "UPDATE notifications SET actor_type = 'Role' WHERE actor_type = 'Agent'"
    execute "UPDATE notifications SET notifiable_type = 'Role' WHERE notifiable_type = 'Agent'"
    execute "UPDATE notifications SET recipient_type = 'Role' WHERE recipient_type = 'Agent'"

    execute "UPDATE audit_events SET actor_type = 'Role' WHERE actor_type = 'Agent'"
    execute "UPDATE audit_events SET auditable_type = 'Role' WHERE auditable_type = 'Agent'"

    execute "UPDATE config_versions SET author_type = 'Role' WHERE author_type = 'Agent'"
    execute "UPDATE config_versions SET versionable_type = 'Role' WHERE versionable_type = 'Agent'"

    execute "UPDATE documents SET author_type = 'Role' WHERE author_type = 'Agent'"
    execute "UPDATE documents SET last_editor_type = 'Role' WHERE last_editor_type = 'Agent'"

    execute "UPDATE messages SET author_type = 'Role' WHERE author_type = 'Agent'"

    # Update polymorphic IDs (agent_id → role_id) for notifications
    execute <<~SQL
      UPDATE notifications
      SET actor_id = (SELECT roles.id FROM roles WHERE roles.agent_id = notifications.actor_id)
      WHERE actor_type = 'Role'
        AND actor_id IN (SELECT agent_id FROM roles WHERE agent_id IS NOT NULL)
    SQL

    execute <<~SQL
      UPDATE notifications
      SET notifiable_id = (SELECT roles.id FROM roles WHERE roles.agent_id = notifications.notifiable_id)
      WHERE notifiable_type = 'Role'
        AND notifiable_id IN (SELECT agent_id FROM roles WHERE agent_id IS NOT NULL)
    SQL

    execute <<~SQL
      UPDATE notifications
      SET recipient_id = (SELECT roles.id FROM roles WHERE roles.agent_id = notifications.recipient_id)
      WHERE recipient_type = 'Role'
        AND recipient_id IN (SELECT agent_id FROM roles WHERE agent_id IS NOT NULL)
    SQL

    # Update polymorphic IDs for audit_events
    execute <<~SQL
      UPDATE audit_events
      SET actor_id = (SELECT roles.id FROM roles WHERE roles.agent_id = audit_events.actor_id)
      WHERE actor_type = 'Role'
        AND actor_id IN (SELECT agent_id FROM roles WHERE agent_id IS NOT NULL)
    SQL

    execute <<~SQL
      UPDATE audit_events
      SET auditable_id = (SELECT roles.id FROM roles WHERE roles.agent_id = audit_events.auditable_id)
      WHERE auditable_type = 'Role'
        AND auditable_id IN (SELECT agent_id FROM roles WHERE agent_id IS NOT NULL)
    SQL

    # Update polymorphic IDs for config_versions
    execute <<~SQL
      UPDATE config_versions
      SET author_id = (SELECT roles.id FROM roles WHERE roles.agent_id = config_versions.author_id)
      WHERE author_type = 'Role'
        AND author_id IN (SELECT agent_id FROM roles WHERE agent_id IS NOT NULL)
    SQL

    execute <<~SQL
      UPDATE config_versions
      SET versionable_id = (SELECT roles.id FROM roles WHERE roles.agent_id = config_versions.versionable_id)
      WHERE versionable_type = 'Role'
        AND versionable_id IN (SELECT agent_id FROM roles WHERE agent_id IS NOT NULL)
    SQL

    # Update polymorphic IDs for documents
    execute <<~SQL
      UPDATE documents
      SET author_id = (SELECT roles.id FROM roles WHERE roles.agent_id = documents.author_id)
      WHERE author_type = 'Role'
        AND author_id IN (SELECT agent_id FROM roles WHERE agent_id IS NOT NULL)
    SQL

    execute <<~SQL
      UPDATE documents
      SET last_editor_id = (SELECT roles.id FROM roles WHERE roles.agent_id = documents.last_editor_id)
      WHERE last_editor_type = 'Role'
        AND last_editor_id IN (SELECT agent_id FROM roles WHERE agent_id IS NOT NULL)
    SQL

    # Update polymorphic IDs for messages
    execute <<~SQL
      UPDATE messages
      SET author_id = (SELECT roles.id FROM roles WHERE roles.agent_id = messages.author_id)
      WHERE author_type = 'Role'
        AND author_id IN (SELECT agent_id FROM roles WHERE agent_id IS NOT NULL)
    SQL

    # Step 4: Remove old FKs that reference agents table
    remove_foreign_key :agent_documents, :agents
    remove_foreign_key :agent_hooks, :agents
    remove_foreign_key :agent_runs, :agents
    remove_foreign_key :agent_skills, :agents
    remove_foreign_key :approval_gates, :agents
    remove_foreign_key :goal_evaluations, :agents
    remove_foreign_key :goals, :agents
    remove_foreign_key :heartbeat_events, :agents
    remove_foreign_key :tasks, column: :assignee_id
    remove_foreign_key :roles, :agents
    remove_foreign_key :hook_executions, :agent_hooks

    # Step 5: Rename tables
    rename_table :agent_skills, :role_skills
    rename_table :agent_hooks, :role_hooks
    rename_table :agent_runs, :role_runs
    rename_table :agent_documents, :role_documents

    # Step 6: Rename FK columns in renamed tables
    rename_column :role_skills, :agent_id, :role_id
    rename_column :role_hooks, :agent_id, :role_id
    rename_column :role_runs, :agent_id, :role_id
    rename_column :role_documents, :agent_id, :role_id

    # Rename in tables that kept their names
    rename_column :approval_gates, :agent_id, :role_id
    rename_column :heartbeat_events, :agent_id, :role_id
    rename_column :goals, :agent_id, :role_id
    rename_column :goal_evaluations, :agent_id, :role_id
    rename_column :hook_executions, :agent_hook_id, :role_hook_id

    # Step 7: Drop agent_id from roles, drop agents table
    remove_column :roles, :agent_id
    drop_table :agents

    # Step 8: Add new FKs pointing to roles
    add_foreign_key :role_skills, :roles
    add_foreign_key :role_hooks, :roles
    add_foreign_key :role_runs, :roles
    add_foreign_key :role_documents, :roles
    add_foreign_key :approval_gates, :roles, column: :role_id
    add_foreign_key :heartbeat_events, :roles, column: :role_id
    add_foreign_key :goals, :roles, column: :role_id
    add_foreign_key :goal_evaluations, :roles, column: :role_id
    add_foreign_key :tasks, :roles, column: :assignee_id
    add_foreign_key :hook_executions, :role_hooks
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
