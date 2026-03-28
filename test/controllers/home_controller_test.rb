require "test_helper"

# HomeController is now superseded by DashboardController as the root page.
# These tests verify root route behavior which now serves the dashboard.
class HomeControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  test "should redirect unauthenticated user to login" do
    get root_url
    assert_redirected_to new_session_url
  end

  test "should show dashboard with active company for authenticated user" do
    sign_in_as(@user)
    get root_url
    assert_response :success
    # User :one auto-selects first company (acme) via SetCurrentCompany concern
    assert_select "h1", "Acme AI Corp"
  end

  test "should redirect to new company page when user has no companies" do
    # Create a user with no memberships
    user_without_company = User.create!(email_address: "lonely@example.com", password: "password", password_confirmation: "password")
    sign_in_as(user_without_company)
    get root_url
    assert_redirected_to new_company_url
  end

  test "root page shows mission when present" do
    sign_in_as(@user)
    post company_switch_url(companies(:acme))
    get root_url
    assert_response :success
    assert_select ".dashboard-mission"
    assert_select ".dashboard-mission__title", text: /Build the best AI platform/
    assert_select ".progress-bar"
  end

  test "root page shows goals link" do
    sign_in_as(@user)
    get root_url
    assert_response :success
    assert_select "a[href='#{goals_path}']", text: "Goals"
  end

  test "root page works without mission" do
    # Switch to a company with no goals
    no_goals_company = Company.create!(name: "No Goals Co")
    no_goals_company.memberships.create!(user: @user, role: :owner)

    sign_in_as(@user)
    post company_switch_url(no_goals_company)
    get root_url
    assert_response :success
    assert_select ".dashboard-mission", count: 0
    assert_select "h1", "No Goals Co"
  end
end
