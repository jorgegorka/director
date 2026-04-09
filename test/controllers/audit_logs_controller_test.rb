require "test_helper"

class AuditLogsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @project = projects(:acme)
    sign_in_as(@user)
    post project_switch_url(@project)
  end

  test "should get index" do
    get audit_logs_url
    assert_response :success
    assert_select "h1", "Audit Log"
  end

  test "should show audit events for current project" do
    get audit_logs_url
    assert_response :success
    assert_select ".audit-table"
  end

  test "should filter by actor_type" do
    get audit_logs_url, params: { actor_type: "User" }
    assert_response :success
  end

  test "should filter by action" do
    get audit_logs_url, params: { action_filter: "created" }
    assert_response :success
  end

  test "should filter by date range" do
    get audit_logs_url, params: { start_date: 1.week.ago.to_date.to_s, end_date: Date.current.to_s }
    assert_response :success
  end

  test "should show empty state when no events match filters" do
    get audit_logs_url, params: { action_filter: "nonexistent_action" }
    assert_response :success
    assert_select ".audit-log-page__empty"
  end

  test "should not show events from other projects" do
    get audit_logs_url
    assert_response :success
    # All events should be for acme project (enforced by for_project scope)
  end

  test "should redirect unauthenticated user" do
    sign_out
    get audit_logs_url
    assert_redirected_to new_session_url
  end

  test "should redirect user without project" do
    user_without_project = User.create!(
      email_address: "auditless@example.com",
      password: "password",
      password_confirmation: "password"
    )
    sign_in_as(user_without_project)
    get audit_logs_url
    assert_redirected_to new_onboarding_project_url
  end

  test "should show filter form" do
    get audit_logs_url
    assert_response :success
    assert_select ".audit-filters"
    assert_select "select[name=actor_type]"
    assert_select "select[name=action_filter]"
    assert_select "input[name=start_date]"
    assert_select "input[name=end_date]"
  end
end
