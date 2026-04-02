# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_04_02_223039) do
  create_table "approval_gates", force: :cascade do |t|
    t.string "action_type", null: false
    t.datetime "created_at", null: false
    t.boolean "enabled", default: true, null: false
    t.bigint "role_id", null: false
    t.datetime "updated_at", null: false
    t.index ["role_id", "action_type"], name: "index_approval_gates_on_agent_and_action_type", unique: true
    t.index ["role_id"], name: "index_approval_gates_on_role_id"
  end

  create_table "audit_events", force: :cascade do |t|
    t.string "action", null: false
    t.bigint "actor_id", null: false
    t.string "actor_type", null: false
    t.bigint "auditable_id", null: false
    t.string "auditable_type", null: false
    t.bigint "company_id"
    t.datetime "created_at", null: false
    t.json "metadata", default: {}, null: false
    t.index ["action"], name: "index_audit_events_on_action"
    t.index ["actor_type", "actor_id"], name: "index_audit_events_on_actor"
    t.index ["auditable_type", "auditable_id", "created_at"], name: "index_audit_events_on_auditable_and_created_at"
    t.index ["auditable_type", "auditable_id"], name: "index_audit_events_on_auditable"
    t.index ["company_id", "action"], name: "index_audit_events_on_company_and_action"
    t.index ["company_id", "created_at"], name: "index_audit_events_on_company_and_time"
    t.index ["company_id"], name: "index_audit_events_on_company_id"
  end

  create_table "companies", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "max_concurrent_agents", default: 0, null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
  end

  create_table "config_versions", force: :cascade do |t|
    t.string "action", null: false
    t.bigint "author_id"
    t.string "author_type"
    t.json "changeset", default: {}, null: false
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.json "snapshot", default: {}, null: false
    t.datetime "updated_at", null: false
    t.bigint "versionable_id", null: false
    t.string "versionable_type", null: false
    t.index ["author_type", "author_id"], name: "index_config_versions_on_author"
    t.index ["company_id"], name: "index_config_versions_on_company_id"
    t.index ["versionable_type", "versionable_id", "created_at"], name: "index_config_versions_on_versionable_and_time"
    t.index ["versionable_type", "versionable_id"], name: "index_config_versions_on_versionable"
  end

  create_table "document_taggings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "document_id", null: false
    t.integer "document_tag_id", null: false
    t.datetime "updated_at", null: false
    t.index ["document_id", "document_tag_id"], name: "index_document_taggings_on_document_id_and_document_tag_id", unique: true
    t.index ["document_id"], name: "index_document_taggings_on_document_id"
    t.index ["document_tag_id"], name: "index_document_taggings_on_document_tag_id"
  end

  create_table "document_tags", force: :cascade do |t|
    t.integer "company_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "name"], name: "index_document_tags_on_company_id_and_name", unique: true
    t.index ["company_id"], name: "index_document_tags_on_company_id"
  end

  create_table "documents", force: :cascade do |t|
    t.integer "author_id", null: false
    t.string "author_type", null: false
    t.text "body", null: false
    t.integer "company_id", null: false
    t.datetime "created_at", null: false
    t.integer "last_editor_id"
    t.string "last_editor_type"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["author_type", "author_id"], name: "index_documents_on_author_type_and_author_id"
    t.index ["company_id"], name: "index_documents_on_company_id"
    t.index ["last_editor_type", "last_editor_id"], name: "index_documents_on_last_editor_type_and_last_editor_id"
  end

  create_table "goal_evaluations", force: :cascade do |t|
    t.integer "attempt_number", null: false
    t.integer "company_id", null: false
    t.integer "cost_cents"
    t.datetime "created_at", null: false
    t.text "feedback", null: false
    t.integer "goal_id", null: false
    t.integer "result", null: false
    t.integer "role_id", null: false
    t.integer "task_id", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_goal_evaluations_on_company_id"
    t.index ["goal_id"], name: "index_goal_evaluations_on_goal_id"
    t.index ["role_id"], name: "index_goal_evaluations_on_role_id"
    t.index ["task_id", "attempt_number"], name: "index_goal_evaluations_on_task_id_and_attempt_number", unique: true
    t.index ["task_id"], name: "index_goal_evaluations_on_task_id"
  end

  create_table "goals", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.integer "completion_percentage", default: 0, null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.bigint "parent_id"
    t.integer "position", default: 0, null: false
    t.integer "role_id"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "parent_id"], name: "index_goals_on_company_id_and_parent_id"
    t.index ["company_id"], name: "index_goals_on_company_id"
    t.index ["parent_id"], name: "index_goals_on_parent_id"
    t.index ["role_id"], name: "index_goals_on_role_id"
  end

  create_table "heartbeat_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "delivered_at"
    t.json "metadata", default: {}, null: false
    t.json "request_payload", default: {}, null: false
    t.json "response_payload", default: {}, null: false
    t.bigint "role_id", null: false
    t.integer "status", default: 0, null: false
    t.string "trigger_source"
    t.integer "trigger_type", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["role_id", "created_at"], name: "index_heartbeat_events_on_agent_and_time"
    t.index ["role_id", "trigger_type"], name: "index_heartbeat_events_on_agent_and_trigger"
    t.index ["role_id"], name: "index_heartbeat_events_on_role_id"
    t.index ["status"], name: "index_heartbeat_events_on_status"
  end

  create_table "hook_executions", force: :cascade do |t|
    t.integer "company_id", null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.text "error_message"
    t.json "input_payload", default: {}, null: false
    t.json "output_payload", default: {}, null: false
    t.integer "role_hook_id", null: false
    t.datetime "started_at"
    t.integer "status", default: 0, null: false
    t.integer "task_id", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_hook_executions_on_company_id"
    t.index ["role_hook_id", "status"], name: "index_hook_executions_on_role_hook_id_and_status"
    t.index ["task_id", "created_at"], name: "index_hook_executions_on_task_id_and_created_at"
  end

  create_table "invitations", force: :cascade do |t|
    t.datetime "accepted_at"
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.datetime "expires_at", null: false
    t.bigint "inviter_id", null: false
    t.integer "role", default: 0, null: false
    t.integer "status", default: 0, null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "email_address"], name: "index_invitations_on_company_and_email_pending", unique: true, where: "(status = 0)"
    t.index ["company_id"], name: "index_invitations_on_company_id"
    t.index ["inviter_id"], name: "index_invitations_on_inviter_id"
    t.index ["token"], name: "index_invitations_on_token", unique: true
  end

  create_table "memberships", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.integer "role", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["company_id", "user_id"], name: "index_memberships_on_company_id_and_user_id", unique: true
    t.index ["company_id"], name: "index_memberships_on_company_id"
    t.index ["user_id"], name: "index_memberships_on_user_id"
  end

  create_table "messages", force: :cascade do |t|
    t.bigint "author_id", null: false
    t.string "author_type", null: false
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.integer "message_type", default: 0, null: false
    t.bigint "parent_id"
    t.bigint "task_id", null: false
    t.datetime "updated_at", null: false
    t.index ["author_type", "author_id"], name: "index_messages_on_author"
    t.index ["parent_id"], name: "index_messages_on_parent_id"
    t.index ["task_id", "created_at"], name: "index_messages_on_task_id_and_created_at"
    t.index ["task_id"], name: "index_messages_on_task_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.string "action", null: false
    t.bigint "actor_id"
    t.string "actor_type"
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.json "metadata", default: {}, null: false
    t.bigint "notifiable_id"
    t.string "notifiable_type"
    t.datetime "read_at"
    t.bigint "recipient_id", null: false
    t.string "recipient_type", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "created_at"], name: "index_notifications_on_company_and_time"
    t.index ["company_id"], name: "index_notifications_on_company_id"
    t.index ["notifiable_type", "notifiable_id"], name: "index_notifications_on_notifiable"
    t.index ["recipient_type", "recipient_id", "read_at"], name: "index_notifications_on_recipient_and_read"
  end

  create_table "pending_hires", force: :cascade do |t|
    t.integer "budget_cents", null: false
    t.integer "company_id", null: false
    t.datetime "created_at", null: false
    t.datetime "resolved_at"
    t.integer "resolved_by_id"
    t.integer "role_id", null: false
    t.integer "status", default: 0, null: false
    t.string "template_role_title", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "status"], name: "index_pending_hires_on_company_id_and_status"
    t.index ["company_id"], name: "index_pending_hires_on_company_id"
    t.index ["resolved_by_id"], name: "index_pending_hires_on_resolved_by_id"
    t.index ["role_id"], name: "index_pending_hires_on_role_id"
  end

  create_table "role_categories", force: :cascade do |t|
    t.integer "company_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.text "job_spec", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "name"], name: "index_role_categories_on_company_id_and_name", unique: true
    t.index ["company_id"], name: "index_role_categories_on_company_id"
  end

  create_table "role_hooks", force: :cascade do |t|
    t.json "action_config", default: {}, null: false
    t.integer "action_type", default: 0, null: false
    t.integer "company_id", null: false
    t.json "conditions", default: {}, null: false
    t.datetime "created_at", null: false
    t.boolean "enabled", default: true, null: false
    t.string "lifecycle_event", null: false
    t.string "name"
    t.integer "position", default: 0, null: false
    t.integer "role_id", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_role_hooks_on_company_id"
    t.index ["role_id", "enabled"], name: "index_role_hooks_on_role_id_and_enabled"
    t.index ["role_id", "lifecycle_event"], name: "index_role_hooks_on_role_id_and_lifecycle_event"
    t.index ["role_id"], name: "index_role_hooks_on_role_id"
  end

  create_table "role_runs", force: :cascade do |t|
    t.string "claude_session_id"
    t.integer "company_id", null: false
    t.datetime "completed_at"
    t.integer "cost_cents"
    t.datetime "created_at", null: false
    t.text "error_message"
    t.integer "exit_code"
    t.integer "goal_id"
    t.text "log_output"
    t.integer "role_id", null: false
    t.datetime "started_at"
    t.integer "status", default: 0, null: false
    t.integer "task_id"
    t.string "trigger_type"
    t.datetime "updated_at", null: false
    t.index ["claude_session_id"], name: "index_role_runs_on_claude_session_id"
    t.index ["company_id", "created_at"], name: "index_role_runs_on_company_id_and_created_at"
    t.index ["company_id"], name: "index_role_runs_on_company_id"
    t.index ["goal_id"], name: "index_role_runs_on_goal_id"
    t.index ["role_id", "created_at"], name: "index_role_runs_on_role_id_and_created_at"
    t.index ["role_id", "status"], name: "index_role_runs_on_role_id_and_status"
    t.index ["role_id"], name: "index_role_runs_on_role_id"
    t.index ["task_id"], name: "index_role_runs_on_task_id"
  end

  create_table "role_skills", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "role_id", null: false
    t.integer "skill_id", null: false
    t.datetime "updated_at", null: false
    t.index ["role_id", "skill_id"], name: "index_role_skills_on_role_id_and_skill_id", unique: true
    t.index ["role_id"], name: "index_role_skills_on_role_id"
    t.index ["skill_id"], name: "index_role_skills_on_skill_id"
  end

  create_table "roles", force: :cascade do |t|
    t.json "adapter_config", default: {}, null: false
    t.integer "adapter_type"
    t.string "api_token"
    t.boolean "auto_hire_enabled", default: false, null: false
    t.integer "budget_cents"
    t.date "budget_period_start"
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.boolean "heartbeat_enabled", default: false, null: false
    t.integer "heartbeat_interval"
    t.text "job_spec"
    t.datetime "last_heartbeat_at"
    t.bigint "parent_id"
    t.text "pause_reason"
    t.datetime "paused_at"
    t.integer "role_category_id"
    t.integer "status", default: 0, null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.string "working_directory"
    t.index ["api_token"], name: "index_roles_on_api_token", unique: true
    t.index ["company_id", "title"], name: "index_roles_on_company_id_and_title", unique: true
    t.index ["company_id"], name: "index_roles_on_company_id"
    t.index ["parent_id"], name: "index_roles_on_parent_id"
    t.index ["role_category_id"], name: "index_roles_on_role_category_id"
    t.index ["status"], name: "index_roles_on_status"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "skill_documents", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "document_id", null: false
    t.integer "skill_id", null: false
    t.datetime "updated_at", null: false
    t.index ["document_id"], name: "index_skill_documents_on_document_id"
    t.index ["skill_id", "document_id"], name: "index_skill_documents_on_skill_id_and_document_id", unique: true
    t.index ["skill_id"], name: "index_skill_documents_on_skill_id"
  end

  create_table "skills", force: :cascade do |t|
    t.boolean "builtin", default: true, null: false
    t.string "category"
    t.integer "company_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.text "markdown", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "category"], name: "index_skills_on_company_id_and_category"
    t.index ["company_id", "key"], name: "index_skills_on_company_id_and_key", unique: true
    t.index ["company_id"], name: "index_skills_on_company_id"
  end

  create_table "task_documents", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "document_id", null: false
    t.integer "task_id", null: false
    t.datetime "updated_at", null: false
    t.index ["document_id"], name: "index_task_documents_on_document_id"
    t.index ["task_id", "document_id"], name: "index_task_documents_on_task_id_and_document_id", unique: true
    t.index ["task_id"], name: "index_task_documents_on_task_id"
  end

  create_table "tasks", force: :cascade do |t|
    t.bigint "assignee_id"
    t.bigint "company_id", null: false
    t.datetime "completed_at"
    t.integer "completion_percentage", default: 0, null: false
    t.integer "cost_cents"
    t.datetime "created_at", null: false
    t.bigint "creator_id"
    t.text "description"
    t.datetime "due_at"
    t.bigint "goal_id"
    t.bigint "parent_task_id"
    t.integer "priority", default: 1, null: false
    t.datetime "reviewed_at"
    t.integer "reviewed_by_id"
    t.integer "status", default: 0, null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["assignee_id", "status"], name: "index_tasks_on_assignee_id_and_status"
    t.index ["assignee_id"], name: "index_tasks_on_assignee_id"
    t.index ["company_id", "status"], name: "index_tasks_on_company_id_and_status"
    t.index ["company_id"], name: "index_tasks_on_company_id"
    t.index ["creator_id"], name: "index_tasks_on_creator_id"
    t.index ["goal_id"], name: "index_tasks_on_goal_id"
    t.index ["parent_task_id"], name: "index_tasks_on_parent_task_id"
    t.index ["reviewed_by_id"], name: "index_tasks_on_reviewed_by_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "approval_gates", "roles"
  add_foreign_key "audit_events", "companies"
  add_foreign_key "config_versions", "companies"
  add_foreign_key "document_taggings", "document_tags"
  add_foreign_key "document_taggings", "documents"
  add_foreign_key "document_tags", "companies"
  add_foreign_key "documents", "companies"
  add_foreign_key "goal_evaluations", "companies"
  add_foreign_key "goal_evaluations", "goals"
  add_foreign_key "goal_evaluations", "roles"
  add_foreign_key "goal_evaluations", "tasks"
  add_foreign_key "goals", "companies"
  add_foreign_key "goals", "goals", column: "parent_id"
  add_foreign_key "goals", "roles"
  add_foreign_key "heartbeat_events", "roles"
  add_foreign_key "hook_executions", "companies"
  add_foreign_key "hook_executions", "role_hooks"
  add_foreign_key "hook_executions", "tasks"
  add_foreign_key "invitations", "companies"
  add_foreign_key "invitations", "users", column: "inviter_id"
  add_foreign_key "memberships", "companies"
  add_foreign_key "memberships", "users"
  add_foreign_key "messages", "messages", column: "parent_id"
  add_foreign_key "messages", "tasks"
  add_foreign_key "notifications", "companies"
  add_foreign_key "pending_hires", "companies"
  add_foreign_key "pending_hires", "roles"
  add_foreign_key "pending_hires", "users", column: "resolved_by_id"
  add_foreign_key "role_categories", "companies"
  add_foreign_key "role_hooks", "companies"
  add_foreign_key "role_hooks", "roles"
  add_foreign_key "role_runs", "companies"
  add_foreign_key "role_runs", "roles"
  add_foreign_key "role_runs", "tasks"
  add_foreign_key "role_skills", "roles"
  add_foreign_key "role_skills", "skills"
  add_foreign_key "roles", "companies"
  add_foreign_key "roles", "role_categories"
  add_foreign_key "roles", "roles", column: "parent_id"
  add_foreign_key "sessions", "users"
  add_foreign_key "skill_documents", "documents"
  add_foreign_key "skill_documents", "skills"
  add_foreign_key "skills", "companies"
  add_foreign_key "task_documents", "documents"
  add_foreign_key "task_documents", "tasks"
  add_foreign_key "tasks", "companies"
  add_foreign_key "tasks", "goals"
  add_foreign_key "tasks", "roles", column: "assignee_id"
  add_foreign_key "tasks", "roles", column: "creator_id"
  add_foreign_key "tasks", "roles", column: "reviewed_by_id"
  add_foreign_key "tasks", "tasks", column: "parent_task_id"
end
