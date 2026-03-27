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

ActiveRecord::Schema[8.1].define(version: 2026_03_27_103456) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "agent_capabilities", force: :cascade do |t|
    t.bigint "agent_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["agent_id", "name"], name: "index_agent_capabilities_on_agent_id_and_name", unique: true
    t.index ["agent_id"], name: "index_agent_capabilities_on_agent_id"
  end

  create_table "agents", force: :cascade do |t|
    t.jsonb "adapter_config", default: {}, null: false
    t.integer "adapter_type", default: 0, null: false
    t.string "api_token"
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.datetime "last_heartbeat_at"
    t.string "name", null: false
    t.text "pause_reason"
    t.datetime "paused_at"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["api_token"], name: "index_agents_on_api_token", unique: true
    t.index ["company_id", "name"], name: "index_agents_on_company_id_and_name", unique: true
    t.index ["company_id"], name: "index_agents_on_company_id"
    t.index ["status"], name: "index_agents_on_status"
  end

  create_table "audit_events", force: :cascade do |t|
    t.string "action", null: false
    t.bigint "actor_id", null: false
    t.string "actor_type", null: false
    t.bigint "auditable_id", null: false
    t.string "auditable_type", null: false
    t.datetime "created_at", null: false
    t.jsonb "metadata", default: {}, null: false
    t.index ["action"], name: "index_audit_events_on_action"
    t.index ["actor_type", "actor_id"], name: "index_audit_events_on_actor"
    t.index ["auditable_type", "auditable_id", "created_at"], name: "index_audit_events_on_auditable_and_created_at"
    t.index ["auditable_type", "auditable_id"], name: "index_audit_events_on_auditable"
  end

  create_table "companies", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
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
    t.bigint "parent_id"
    t.bigint "task_id", null: false
    t.datetime "updated_at", null: false
    t.index ["author_type", "author_id"], name: "index_messages_on_author"
    t.index ["parent_id"], name: "index_messages_on_parent_id"
    t.index ["task_id", "created_at"], name: "index_messages_on_task_id_and_created_at"
    t.index ["task_id"], name: "index_messages_on_task_id"
  end

  create_table "roles", force: :cascade do |t|
    t.bigint "agent_id"
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.text "job_spec"
    t.bigint "parent_id"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["agent_id"], name: "index_roles_on_agent_id"
    t.index ["company_id", "title"], name: "index_roles_on_company_id_and_title", unique: true
    t.index ["company_id"], name: "index_roles_on_company_id"
    t.index ["parent_id"], name: "index_roles_on_parent_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "tasks", force: :cascade do |t|
    t.bigint "assignee_id"
    t.bigint "company_id", null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.bigint "creator_id"
    t.text "description"
    t.datetime "due_at"
    t.bigint "parent_task_id"
    t.integer "priority", default: 1, null: false
    t.integer "status", default: 0, null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["assignee_id", "status"], name: "index_tasks_on_assignee_id_and_status"
    t.index ["assignee_id"], name: "index_tasks_on_assignee_id"
    t.index ["company_id", "status"], name: "index_tasks_on_company_id_and_status"
    t.index ["company_id"], name: "index_tasks_on_company_id"
    t.index ["creator_id"], name: "index_tasks_on_creator_id"
    t.index ["parent_task_id"], name: "index_tasks_on_parent_task_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "agent_capabilities", "agents"
  add_foreign_key "agents", "companies"
  add_foreign_key "invitations", "companies"
  add_foreign_key "invitations", "users", column: "inviter_id"
  add_foreign_key "memberships", "companies"
  add_foreign_key "memberships", "users"
  add_foreign_key "messages", "messages", column: "parent_id"
  add_foreign_key "messages", "tasks"
  add_foreign_key "roles", "agents"
  add_foreign_key "roles", "companies"
  add_foreign_key "roles", "roles", column: "parent_id"
  add_foreign_key "sessions", "users"
  add_foreign_key "tasks", "agents", column: "assignee_id"
  add_foreign_key "tasks", "companies"
  add_foreign_key "tasks", "tasks", column: "parent_task_id"
  add_foreign_key "tasks", "users", column: "creator_id"
end
