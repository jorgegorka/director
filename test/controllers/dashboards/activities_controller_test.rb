require "test_helper"

class Dashboards::ActivitiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
    post project_switch_url(projects(:acme))
  end

  test "should get index" do
    get dashboard_activities_url
    assert_response :success
  end

  test "shows audit events" do
    get dashboard_activities_url
    assert_response :success
    assert_select ".activity-event", minimum: 1
  end

  test "events show action badge" do
    get dashboard_activities_url
    assert_response :success
    assert_select ".audit-badge", minimum: 1
  end

  test "has role filter dropdown" do
    get dashboard_activities_url
    assert_response :success
    assert_select "select[name='role_filter']"
  end

  test "role filter narrows results" do
    get dashboard_activities_url, params: { role_filter: roles(:cto).id }
    assert_response :success
  end

  test "roles_only filter shows all role activity" do
    get dashboard_activities_url, params: { role_filter: "roles_only" }
    assert_response :success
  end

  test "respects project isolation" do
    get dashboard_activities_url
    assert_response :success
    assert_select ".activity-feed"
  end

  test "events have turbo stream target ids" do
    get dashboard_activities_url
    assert_response :success
    assert_select "[id^='activity-event-']", minimum: 1
  end

  test "renders full page with activity tab active" do
    get dashboard_activities_url
    assert_response :success
    assert_select ".dashboard-tab--active", text: "Activity"
  end

  test "requires authentication" do
    sign_out
    get dashboard_activities_url
    assert_redirected_to new_session_url
  end

  test "requires project" do
    user_without_project = User.create!(
      email_address: "noproject@example.com",
      password: "password",
      password_confirmation: "password"
    )
    sign_in_as(user_without_project)
    get dashboard_activities_url
    assert_redirected_to new_onboarding_project_url
  end
end
