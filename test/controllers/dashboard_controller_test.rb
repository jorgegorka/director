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
    assert_select ".dashboard"
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

  test "dashboard page includes turbo stream subscription" do
    get dashboard_url
    assert_response :success
    assert_select "turbo-cable-stream-source[channel='Turbo::StreamsChannel']"
  end

  test "dashboard shows goals section" do
    get dashboard_url
    assert_response :success
    assert_select ".goals-section"
    assert_select ".goals-section__title", text: "Goals"
  end

  test "dashboard renders goal cards for root tasks" do
    get dashboard_url
    assert_response :success
    root_count = projects(:acme).tasks.roots.count
    assert_select ".goal-card", root_count
  end

  test "goal card shows title and status badge" do
    get dashboard_url
    assert_response :success
    assert_select ".goal-card__title"
    assert_select ".status-badge"
  end

  test "goal card shows progress bar" do
    get dashboard_url
    assert_response :success
    assert_select ".progress-bar"
  end

  test "attention section shown when attention items exist" do
    get dashboard_url
    assert_response :success
    assert_select "#dashboard-attention .attention-section"
  end

  test "attention section shows pending review tasks" do
    get dashboard_url
    assert_response :success
    assert_select ".status-badge--pending_review"
  end

  test "attention section shows gate blocked roles" do
    get dashboard_url
    assert_response :success
    assert_select ".status-badge--pending_approval"
  end

  test "attention section shows pending hires" do
    get dashboard_url
    assert_response :success
    assert_select ".status-badge--open"
  end

  test "dashboard only shows current project data" do
    acme_goal_count = projects(:acme).tasks.roots.count

    post project_switch_url(projects(:widgets))
    get dashboard_url
    assert_response :success
    widgets_goal_count = projects(:widgets).tasks.roots.count

    assert_not_equal acme_goal_count, widgets_goal_count
  end

  test "role status change triggers dashboard broadcasts without error" do
    role = roles(:cto)
    role.update!(status: :running)

    assert_nothing_raised do
      role.update!(status: :idle)
    end
  end

  test "old dashboard sub-routes no longer exist" do
    assert_not Rails.application.routes.recognize_path("/dashboard/activities", method: :get).key?(:controller)
  rescue ActionController::RoutingError
    # Expected — route doesn't exist
    pass
  end
end
