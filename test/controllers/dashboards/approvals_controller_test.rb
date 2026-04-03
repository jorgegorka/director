require "test_helper"

class Dashboards::ApprovalsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
    post company_switch_url(companies(:acme))
  end

  test "should get index" do
    get dashboard_approvals_url
    assert_response :success
  end

  test "renders approval sections" do
    get dashboard_approvals_url
    assert_response :success
    assert_select ".approvals__section", 3
  end

  test "shows gate-blocked roles" do
    get dashboard_approvals_url
    assert_response :success
    assert_select ".approval-card__title", text: /Content Writer/
  end

  test "shows pending hires" do
    get dashboard_approvals_url
    assert_response :success
    assert_select ".approval-card__detail", text: /Marketing Planner/
  end

  test "shows tasks pending review" do
    get dashboard_approvals_url
    assert_response :success
    assert_select ".approval-card__title", text: /Draft marketing plan/
  end

  test "renders full page with approvals tab active" do
    get dashboard_approvals_url
    assert_response :success
    assert_select ".dashboard-tab--active", text: /Approvals/
  end

  test "requires authentication" do
    sign_out
    get dashboard_approvals_url
    assert_redirected_to new_session_url
  end

  test "requires company" do
    user_without_company = User.create!(
      email_address: "nocompany@example.com",
      password: "password",
      password_confirmation: "password"
    )
    sign_in_as(user_without_company)
    get dashboard_approvals_url
    assert_redirected_to new_company_url
  end
end
