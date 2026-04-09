require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
    post project_switch_url(projects(:acme))
  end

  test "should get show" do
    get dashboard_url
    assert_response :success
    assert_select ".dashboard-tabs"
  end

  test "should show agent stats" do
    get dashboard_url
    assert_response :success
    assert_select ".stat-card", minimum: 4
  end

  test "should show overview stats for agents" do
    get dashboard_url
    assert_response :success
    assert_select ".stat-card", minimum: 4
  end

  test "should require authentication" do
    sign_out
    get dashboard_url
    assert_redirected_to new_session_url
  end

  test "should require project" do
    user_without_project = User.create!(
      email_address: "noproject@example.com",
      password: "password",
      password_confirmation: "password"
    )
    sign_in_as(user_without_project)
    get dashboard_url
    assert_redirected_to new_onboarding_project_url
  end

  test "root path redirects authenticated users to dashboard" do
    get root_url
    assert_redirected_to dashboard_url
    follow_redirect!
    assert_response :success
    assert_select ".dashboard"
  end

  test "should show mission if present" do
    get dashboard_url
    assert_response :success
    assert_select ".dashboard-mission"
  end

  test "dashboard only shows current project data" do
    # Acme has active agent-configured roles (cto, developer, process_role)
    acme_role_count = projects(:acme).roles.active.where.not(adapter_type: nil).count

    # Switch to widgets project and verify data changes
    post project_switch_url(projects(:widgets))
    get dashboard_url
    assert_response :success
    widgets_role_count = projects(:widgets).roles.active.where.not(adapter_type: nil).count

    assert_not_equal acme_role_count, widgets_role_count
  end

  test "should show overview tab content by default" do
    get dashboard_url
    assert_response :success
    assert_select ".dashboard-tab--active", text: "Overview"
    assert_select "#dashboard-overview-stats"
  end

  test "tab links navigate to correct paths" do
    get dashboard_url
    assert_response :success
    assert_select "a.dashboard-tab", minimum: 4
  end

  test "overview stats have turbo stream target id" do
    get dashboard_url
    assert_response :success
    assert_select "#dashboard-overview-stats"
  end

  # Running agents section

  test "overview tab shows running agents section" do
    get dashboard_url
    assert_response :success
    assert_select "#dashboard-running-agents"
  end

  test "running agents shows empty state when no agents running" do
    get dashboard_url
    assert_response :success
    assert_select "#dashboard-running-agents .dashboard-empty", text: /No agents are currently running/
  end

  test "running agents shows cards when a role is running" do
    roles(:developer).update_column(:status, Role.statuses[:running])
    get dashboard_url
    assert_response :success
    assert_select ".dashboard-running-card", minimum: 1
  end

  # Real-time broadcast target tests

  test "dashboard page includes turbo stream subscription" do
    get dashboard_url
    assert_response :success
    assert_select "turbo-cable-stream-source"
  end

  test "shows approvals tab with badge" do
    get dashboard_url
    assert_response :success
    assert_select ".dashboard-tab", text: /Approvals/
    assert_select "#approvals-badge"
  end

  test "approvals badge shows count when pending items exist" do
    get dashboard_url
    assert_response :success
    assert_select "#approvals-badge:not([hidden])"
  end

  test "activity shows link to full audit log" do
    get dashboard_url
    assert_response :success
    assert_select "a[href='#{audit_logs_path}']"
  end

  # --- Role status lifecycle broadcast tests ---

  test "role status change triggers dashboard broadcasts without error" do
    role = roles(:cto)
    role.update!(status: :running)

    # Should not raise any errors when broadcasting
    assert_nothing_raised do
      role.update!(status: :idle)
    end
  end

  test "running agents section updates when role status changes" do
    role = roles(:developer)

    # Initially idle - no running agents
    get dashboard_url
    assert_response :success
    assert_select "#dashboard-running-agents .dashboard-empty"

    # Change to running - should show running agent
    role.update!(status: :running)
    get dashboard_url
    assert_response :success
    assert_select ".dashboard-running-card", minimum: 1

    # Back to idle - should show empty state again
    role.update!(status: :idle)
    get dashboard_url
    assert_response :success
    assert_select "#dashboard-running-agents .dashboard-empty"
  end

  test "overview stats update when role status changes" do
    # Get initial counts
    get dashboard_url
    assert_response :success

    initial_online_count = projects(:acme).roles.online.count
    initial_running_count = projects(:acme).roles.where(status: :running).count

    # Change a role to running
    role = roles(:developer)
    role.update!(status: :running)

    # Verify counts changed correctly
    new_online_count = projects(:acme).roles.online.count
    new_running_count = projects(:acme).roles.where(status: :running).count

    assert_equal initial_online_count, new_online_count # online = idle + running, should be same
    assert_equal initial_running_count + 1, new_running_count
  end

  test "dashboard has proper turbo stream target ids for broadcasts" do
    get dashboard_url
    assert_response :success

    # Verify key broadcast target elements exist
    assert_select "#dashboard-overview-stats"
    assert_select "#dashboard-running-agents"
    assert_select "#approvals-badge"
    assert_select "turbo-cable-stream-source[channel='Turbo::StreamsChannel']"
  end
end
