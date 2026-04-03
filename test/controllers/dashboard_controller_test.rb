require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
    post company_switch_url(companies(:acme))
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

  test "should show budget summary for agents with budgets" do
    get dashboard_url
    assert_response :success
    assert_select ".dashboard-budget-card", minimum: 1
  end

  test "should require authentication" do
    sign_out
    get dashboard_url
    assert_redirected_to new_session_url
  end

  test "should require company" do
    user_without_company = User.create!(
      email_address: "nocompany@example.com",
      password: "password",
      password_confirmation: "password"
    )
    sign_in_as(user_without_company)
    get dashboard_url
    assert_redirected_to new_company_url
  end

  test "root path shows dashboard" do
    get root_url
    assert_response :success
    assert_select ".dashboard"
  end

  test "should show mission if present" do
    get dashboard_url
    assert_response :success
    assert_select ".dashboard-mission"
  end

  test "dashboard only shows current company data" do
    # Acme has active agent-configured roles (cto, developer, process_role)
    acme_role_count = companies(:acme).roles.active.where.not(adapter_type: nil).count

    # Switch to widgets company and verify data changes
    post company_switch_url(companies(:widgets))
    get dashboard_url
    assert_response :success
    widgets_role_count = companies(:widgets).roles.active.where.not(adapter_type: nil).count

    assert_not_equal acme_role_count, widgets_role_count
  end

  test "should show overview tab content by default" do
    get dashboard_url
    assert_response :success
    assert_select "turbo-frame#tab_content"
    assert_select "#dashboard-overview-stats"
  end

  test "tab links target turbo frame" do
    get dashboard_url
    assert_response :success
    assert_select "a[data-turbo-frame='tab_content']", minimum: 3
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
    get root_url
    assert_response :success
    assert_select "a[href='#{audit_logs_path}']"
  end
end
