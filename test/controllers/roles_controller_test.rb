require "test_helper"

class RolesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @company = companies(:acme)
    sign_in_as(@user)
    post company_switch_url(@company)
    @ceo = roles(:ceo)
    @cto = roles(:cto)
    @developer = roles(:developer)
  end

  # --- Index ---

  test "should get index" do
    get roles_url
    assert_response :success
    assert_select ".role-card", minimum: 3
  end

  test "should only show roles for current company" do
    get roles_url
    assert_response :success
    assert_select ".role-card__title", text: "CEO"
    assert_select ".role-card__title", text: "Operations Lead", count: 0
  end

  # --- Show ---

  test "should show role" do
    get role_url(@ceo)
    assert_response :success
    assert_select "h1", "CEO"
  end

  test "should show direct reports on role detail" do
    get role_url(@ceo)
    assert_response :success
    assert_select ".role-card__title", text: "CTO"
  end

  test "should not show role from another company" do
    get role_url(roles(:widgets_lead))
    assert_redirected_to root_url
  end

  test "should show adapter type on detail page" do
    get role_url(@developer)
    assert_response :success
    assert_select ".role-detail__adapter-label", text: "HTTP API"
  end

  # --- New / Create ---

  test "should get new role form" do
    get new_role_url
    assert_response :success
    assert_select "form"
    assert_select "select[name='role[parent_id]']"
  end

  test "should create role" do
    assert_difference("Role.count", 1) do
      post roles_url, params: {
        role: { title: "Designer", description: "UI/UX design", job_spec: "Design interfaces", parent_id: @cto.id, role_category_id: role_categories(:worker).id }
      }
    end
    role = Role.order(:created_at).last
    assert_equal "Designer", role.title
    assert_equal @cto, role.parent
    assert_equal @company, role.company
    assert_redirected_to role_url(role)
  end

  test "should create root role with no parent" do
    assert_difference("Role.count", 1) do
      post roles_url, params: {
        role: { title: "Advisor", description: "External advisor", role_category_id: role_categories(:worker).id }
      }
    end
    role = Role.order(:created_at).last
    assert_nil role.parent_id
  end

  test "should not create role with blank title" do
    assert_no_difference("Role.count") do
      post roles_url, params: { role: { title: "", role_category_id: role_categories(:worker).id } }
    end
    assert_response :unprocessable_entity
  end

  test "should not create role with duplicate title" do
    assert_no_difference("Role.count") do
      post roles_url, params: { role: { title: "CEO", role_category_id: role_categories(:worker).id } }
    end
    assert_response :unprocessable_entity
  end

  test "should create role with adapter config (http)" do
    assert_difference("Role.count", 1) do
      post roles_url, params: {
        role: {
          title: "New HTTP Role",
          adapter_type: "http",
          adapter_config: { url: "https://example.com/api", method: "POST" },
          role_category_id: role_categories(:worker).id
        }
      }
    end
    role = Role.order(:created_at).last
    assert_equal "New HTTP Role", role.title
    assert role.http?
    assert_equal "https://example.com/api", role.adapter_config["url"]
    assert_equal @company, role.company
    assert_redirected_to role_url(role)
  end

  test "should create role with claude_local adapter" do
    assert_difference("Role.count", 1) do
      post roles_url, params: {
        role: {
          title: "Local Claude Role",
          adapter_type: "claude_local",
          adapter_config: { model: "claude-sonnet-4-20250514" },
          role_category_id: role_categories(:worker).id
        }
      }
    end
    role = Role.order(:created_at).last
    assert role.claude_local?
    assert_equal "claude-sonnet-4-20250514", role.adapter_config["model"]
  end

  test "should create role with working_directory" do
    post roles_url, params: { role: { title: "Agent", working_directory: "/projects/website", role_category_id: role_categories(:worker).id } }
    role = Role.find_by(title: "Agent")
    assert_equal "/projects/website", role.working_directory
  end

  # --- Edit / Update ---

  test "should get edit form" do
    get edit_role_url(@cto)
    assert_response :success
    assert_select "form"
  end

  test "should update role" do
    patch role_url(@cto), params: { role: { title: "VP Engineering", description: "Updated description" } }
    assert_redirected_to role_url(@cto)
    @cto.reload
    assert_equal "VP Engineering", @cto.title
    assert_equal "Updated description", @cto.description
  end

  test "should update role parent" do
    patch role_url(@developer), params: { role: { parent_id: @ceo.id } }
    assert_redirected_to role_url(@developer)
    @developer.reload
    assert_equal @ceo, @developer.parent
  end

  test "should update role working_directory" do
    patch role_url(@cto), params: { role: { working_directory: "/projects/website" } }
    assert_redirected_to role_url(@cto)
    @cto.reload
    assert_equal "/projects/website", @cto.working_directory
  end

  test "should not update role with blank title" do
    patch role_url(@cto), params: { role: { title: "" } }
    assert_response :unprocessable_entity
  end

  # --- Destroy ---

  test "should destroy role and re-parent children" do
    assert_difference("Role.count", -1) do
      delete role_url(@cto)
    end
    assert_redirected_to roles_url
    @developer.reload
    assert_equal @ceo.id, @developer.parent_id
  end

  test "should destroy root role and make children root" do
    assert_difference("Role.count", -1) do
      delete role_url(@ceo)
    end
    @cto.reload
    assert_nil @cto.parent_id
  end

  # --- Auth / Scoping ---

  test "should redirect unauthenticated user" do
    sign_out
    get roles_url
    assert_redirected_to new_session_url
  end

  test "should redirect user without company" do
    user_without_company = User.create!(email_address: "lonely@example.com", password: "password", password_confirmation: "password")
    sign_in_as(user_without_company)
    get roles_url
    assert_redirected_to new_company_url
  end

  # --- Heartbeat Schedule ---

  test "should create role with heartbeat schedule" do
    assert_difference("Role.count", 1) do
      post roles_url, params: {
        role: {
          title: "Scheduled Role",
          adapter_type: "http",
          adapter_config: { url: "https://example.com/agent" },
          heartbeat_enabled: "1",
          heartbeat_interval: "15",
          role_category_id: role_categories(:worker).id
        }
      }
    end
    role = Role.order(:created_at).last
    assert role.heartbeat_enabled?
    assert_equal 15, role.heartbeat_interval
  end

  test "should update role heartbeat schedule" do
    patch role_url(@cto), params: {
      role: {
        heartbeat_enabled: "1",
        heartbeat_interval: "30"
      }
    }
    assert_redirected_to role_url(@cto)
    @cto.reload
    assert @cto.heartbeat_enabled?
    assert_equal 30, @cto.heartbeat_interval
  end

  test "should disable role heartbeat" do
    @cto.update_columns(heartbeat_enabled: true, heartbeat_interval: 15)
    patch role_url(@cto), params: {
      role: { heartbeat_enabled: "0" }
    }
    assert_redirected_to role_url(@cto)
    @cto.reload
    assert_not @cto.heartbeat_enabled?
  end

  test "should show heartbeat section on role detail page" do
    get role_url(@cto)
    assert_response :success
    assert_select ".role-detail__kv"
  end

  test "should show heartbeat events on role detail page" do
    get role_url(@cto)
    assert_response :success
    assert_select ".heartbeat-table"
  end

  test "should link to heartbeat history from role page" do
    get role_url(@cto)
    assert_response :success
    assert_select "a[href=?]", role_heartbeats_path(@cto)
  end

  # --- Budget ---

  test "should create role with budget" do
    assert_difference("Role.count") do
      post roles_url, params: { role: {
        title: "Budget Role",
        adapter_type: "http",
        adapter_config: { url: "https://example.com" },
        budget_dollars: "250.00",
        role_category_id: role_categories(:worker).id
      } }
    end
    role = Role.find_by(title: "Budget Role")
    assert_equal 25000, role.budget_cents
    assert_equal Date.current.beginning_of_month, role.budget_period_start
  end

  test "should update role budget" do
    patch role_url(@cto), params: { role: { budget_dollars: "750.00" } }
    assert_redirected_to role_url(@cto)
    @cto.reload
    assert_equal 75000, @cto.budget_cents
  end

  test "should clear budget when empty string submitted" do
    patch role_url(@cto), params: { role: { budget_dollars: "" } }
    assert_redirected_to role_url(@cto)
    @cto.reload
    assert_nil @cto.budget_cents
    assert_nil @cto.budget_period_start
  end

  test "should show budget section on role detail page" do
    get role_url(@cto)
    assert_response :success
    assert_select ".budget-display"
  end

  test "should show no-budget message for role without budget" do
    get role_url(roles(:process_role))
    assert_response :success
    assert_select ".role-detail__empty-note", /No budget configured/
  end

  # --- Role Status Actions ---

  test "should pause role" do
    @cto.update_columns(status: Role.statuses[:idle])
    post pause_role_url(@cto)
    assert_redirected_to role_url(@cto)
    @cto.reload
    assert @cto.paused?
    assert @cto.pause_reason.present?
    assert @cto.paused_at.present?
  end

  test "should not pause already paused role" do
    @cto.update_columns(status: Role.statuses[:paused])
    post pause_role_url(@cto)
    assert_redirected_to role_url(@cto)
    assert_equal "#{@cto.title} is already paused.", flash[:alert]
  end

  test "should resume paused role" do
    @cto.update_columns(status: Role.statuses[:paused], pause_reason: "test", paused_at: Time.current)
    post resume_role_url(@cto)
    assert_redirected_to role_url(@cto)
    @cto.reload
    assert @cto.idle?
    assert_nil @cto.pause_reason
  end

  test "should resume pending_approval role" do
    @cto.update_columns(status: Role.statuses[:pending_approval], pause_reason: "test", paused_at: Time.current)
    post resume_role_url(@cto)
    assert_redirected_to role_url(@cto)
    @cto.reload
    assert @cto.idle?
  end

  test "should terminate role" do
    post terminate_role_url(@cto)
    assert_redirected_to role_url(@cto)
    @cto.reload
    assert @cto.terminated?
  end

  test "should not terminate already terminated role" do
    @cto.update_columns(status: Role.statuses[:terminated])
    post terminate_role_url(@cto)
    assert_redirected_to role_url(@cto)
    assert_equal "#{@cto.title} is already terminated.", flash[:alert]
  end

  test "should run idle role" do
    @cto.update_columns(status: Role.statuses[:idle])
    @cto.role_runs.active.update_all(status: RoleRun.statuses[:cancelled])
    assert_difference("RoleRun.count") do
      post run_role_url(@cto)
    end
    assert_redirected_to role_url(@cto)
    assert_match /has been started/, flash[:notice]
  end

  test "should not run terminated role" do
    @cto.update_columns(status: Role.statuses[:terminated])
    assert_no_difference("RoleRun.count") do
      post run_role_url(@cto)
    end
    assert_redirected_to role_url(@cto)
    assert_equal "Cannot run a terminated role.", flash[:alert]
  end

  test "should not run role with active run" do
    @cto.update_columns(status: Role.statuses[:idle])
    @cto.role_runs.create!(company: @company, status: :queued, trigger_type: :scheduled)
    assert_no_difference("RoleRun.count") do
      post run_role_url(@cto)
    end
    assert_redirected_to role_url(@cto)
    assert_match /already has an active run/, flash[:alert]
  end

  test "should approve pending_approval role" do
    @cto.update_columns(status: Role.statuses[:pending_approval], pause_reason: "Approval required: Task creation gate is active")
    post approve_role_url(@cto)
    assert_redirected_to role_url(@cto)
    @cto.reload
    assert @cto.idle?
    assert_nil @cto.pause_reason
  end

  test "should reject pending_approval role" do
    @cto.update_columns(status: Role.statuses[:pending_approval], pause_reason: "Approval required")
    post reject_role_url(@cto)
    assert_redirected_to role_url(@cto)
    @cto.reload
    assert @cto.paused?
    assert_match /Approval rejected/, @cto.pause_reason
  end

  test "pause records audit event" do
    @cto.update_columns(status: Role.statuses[:idle])
    assert_difference -> { AuditEvent.where(action: "role_paused").count } do
      post pause_role_url(@cto)
    end
  end

  test "resume records audit event" do
    @cto.update_columns(status: Role.statuses[:paused], pause_reason: "test", paused_at: Time.current)
    assert_difference -> { AuditEvent.where(action: "role_resumed").count } do
      post resume_role_url(@cto)
    end
  end

  test "terminate records audit event" do
    assert_difference -> { AuditEvent.where(action: "role_terminated").count } do
      post terminate_role_url(@cto)
    end
  end

  test "approve records gate_approval audit event" do
    @cto.update_columns(status: Role.statuses[:pending_approval], pause_reason: "Approval required")
    assert_difference -> { AuditEvent.where(action: "gate_approval").count } do
      post approve_role_url(@cto)
    end
  end

  test "reject records gate_rejection audit event" do
    @cto.update_columns(status: Role.statuses[:pending_approval], pause_reason: "Approval required")
    assert_difference -> { AuditEvent.where(action: "gate_rejection").count } do
      post reject_role_url(@cto)
    end
  end

  test "approve responds with turbo_stream" do
    @cto.update_columns(status: Role.statuses[:pending_approval], pause_reason: "Approval required")
    post approve_role_url(@cto), headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
    @cto.reload
    assert @cto.idle?
  end

  test "reject responds with turbo_stream" do
    @cto.update_columns(status: Role.statuses[:pending_approval], pause_reason: "Approval required")
    post reject_role_url(@cto), headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
    @cto.reload
    assert @cto.paused?
  end

  # --- Emergency Stop ---

  test "should emergency stop all roles" do
    @company.roles.where.not(adapter_type: nil).update_all(status: Role.statuses[:idle])
    post emergency_stop_company_url(@company)
    assert_redirected_to roles_url
  end

  test "should not allow status actions on other company roles" do
    post pause_role_url(roles(:widgets_lead))
    assert_redirected_to root_url
  end

  # --- Approval Gates ---

  test "should save approval gates on role update" do
    patch role_url(@cto), params: {
      role: {
        gates_submitted: "1",
        gates: {
          task_creation: "1",
          budget_spend: "1"
        }
      }
    }
    assert_redirected_to role_url(@cto)
    @cto.reload
    assert @cto.gate_enabled?("task_creation")
    assert @cto.gate_enabled?("budget_spend")
  end

  test "should disable gates when unchecked" do
    patch role_url(@cto), params: {
      role: {
        gates_submitted: "1",
        gates: {
          task_creation: "1",
          budget_spend: "1"
        }
      }
    }
    patch role_url(@cto), params: {
      role: {
        gates_submitted: "1",
        gates: {}
      }
    }
    assert_redirected_to role_url(@cto)
    @cto.reload
    assert_not @cto.gate_enabled?("task_creation")
    assert_not @cto.gate_enabled?("budget_spend")
  end

  test "should show approval gates section on role detail page" do
    get role_url(@cto)
    assert_response :success
    assert_select ".gate-list", minimum: 0
  end

  test "should show pending approval banner when role is pending" do
    @cto.update_columns(status: Role.statuses[:pending_approval], pause_reason: "Approval required: Task creation gate is active")
    get role_url(@cto)
    assert_response :success
    assert_select ".approval-banner"
  end

  test "should not show pending approval banner for idle role" do
    get role_url(@cto)
    assert_response :success
    assert_select ".approval-banner", count: 0
  end

  # --- Skills: Skill Manager (show page) ---

  test "should show skill manager with checkboxes on role show" do
    get role_url(@cto)
    assert_response :success
    assert_select ".skill-manager"
    assert_select ".skill-manager__category", minimum: 1
  end

  test "should show assigned skills as checked on role show" do
    get role_url(@cto)
    assert_response :success
    assert_select ".skill-manager__toggle--assigned", minimum: 1
  end

  test "should show unassigned skills as unchecked on role show" do
    get role_url(@cto)
    assert_response :success
    assigned_count = css_select(".skill-manager__toggle--assigned").size
    total_count = css_select(".skill-manager__toggle").size
    assert total_count > assigned_count, "Expected unassigned skills to also appear as toggles"
  end

  test "should show skill categories in skill manager" do
    get role_url(@cto)
    assert_response :success
    assert_select ".skill-manager__category-title", minimum: 2
  end

  # --- Skills: Role Card (index page) ---

  test "should show skill tags in role card on index" do
    get roles_url
    assert_response :success
    assert_select ".role-card__skill-tag", minimum: 1
  end
end
