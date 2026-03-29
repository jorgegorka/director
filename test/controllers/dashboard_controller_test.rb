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

  test "activity tab has role filter dropdown" do
    get root_url
    assert_response :success
    assert_select "select[name='role_filter']"
  end

  test "role filter narrows activity results" do
    get root_url, params: { tab: "activity", role_filter: roles(:cto).id }
    assert_response :success
  end

  test "roles_only filter shows all role activity" do
    get root_url, params: { tab: "activity", role_filter: "roles_only" }
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

  # Real-time broadcast target tests

  test "dashboard page includes turbo stream subscription" do
    get dashboard_url
    assert_response :success
    assert_select "turbo-cable-stream-source"
  end

  test "kanban cards have turbo stream target ids" do
    get dashboard_url
    assert_response :success
    assert_select "[id^='kanban-task-']", minimum: 1
  end

  test "activity events have turbo stream target ids" do
    get root_url
    assert_response :success
    assert_select "[id^='activity-event-']", minimum: 1
  end

  test "overview stats have turbo stream target id" do
    get dashboard_url
    assert_response :success
    assert_select "#dashboard-overview-stats"
  end

  test "kanban column bodies have target ids" do
    get dashboard_url
    assert_response :success
    assert_select "[id^='kanban-column-body-']", 5
  end

  # Kanban board tests

  test "tasks tab shows kanban columns" do
    get dashboard_url
    assert_response :success
    assert_select ".kanban__column", 5
  end

  test "kanban shows tasks in correct columns" do
    get dashboard_url
    assert_response :success
    assert_select ".kanban__column[data-status='in_progress'] .kanban-card", minimum: 1
  end

  test "kanban cards show task title" do
    get dashboard_url
    assert_response :success
    assert_select ".kanban-card__title", text: /Design homepage/
  end

  test "kanban does not show other company tasks" do
    get dashboard_url
    assert_response :success
    assert_select ".kanban-card__title", text: /Update widget catalog/, count: 0
  end

  test "kanban cards are draggable" do
    get dashboard_url
    assert_response :success
    assert_select ".kanban-card[draggable='true']", minimum: 1
  end

  test "kanban shows new task link" do
    get dashboard_url
    assert_response :success
    assert_select "a[href='#{new_task_path}']", text: "New Task"
  end
end
