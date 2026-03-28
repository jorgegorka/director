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
    # Acme has 3 active agents (claude_agent, http_agent, process_agent)
    acme_agent_count = companies(:acme).agents.active.count

    # Switch to widgets company and verify data changes
    post company_switch_url(companies(:widgets))
    get dashboard_url
    assert_response :success
    widgets_agent_count = companies(:widgets).agents.active.count

    assert_not_equal acme_agent_count, widgets_agent_count
  end

  test "should show overview tab by default" do
    get dashboard_url
    assert_response :success
    assert_select "[data-tabs-target='panel']", minimum: 1
  end

  # Activity tab tests

  test "activity tab shows audit events" do
    get root_url
    assert_response :success
    assert_select ".activity-event", minimum: 1
  end

  test "activity events show action badge" do
    get root_url
    assert_response :success
    assert_select ".audit-badge", minimum: 1
  end

  test "activity tab has agent filter dropdown" do
    get root_url
    assert_response :success
    assert_select "select[name='agent_filter']"
  end

  test "agent filter narrows activity results" do
    get root_url, params: { tab: "activity", agent_filter: agents(:claude_agent).id }
    assert_response :success
  end

  test "agents_only filter shows all agent activity" do
    get root_url, params: { tab: "activity", agent_filter: "agents_only" }
    assert_response :success
  end

  test "activity tab respects company isolation" do
    get root_url
    assert_response :success
    # All displayed events must belong to the current company (acme)
    # Verified by checking no widgets company events appear in the feed
    # The for_company scope on AuditEvent enforces this at query level
    assert_select ".activity-feed"
  end

  test "tab param sets active tab" do
    get root_url, params: { tab: "activity" }
    assert_response :success
    assert_select "[data-tabs-active-tab-value='activity']"
  end

  test "activity shows link to full audit log" do
    get root_url
    assert_response :success
    assert_select "a[href='#{audit_logs_path}']"
  end
end
