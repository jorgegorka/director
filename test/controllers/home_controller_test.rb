require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  test "should redirect unauthenticated user to login" do
    get root_url
    assert_redirected_to new_session_url
  end

  test "should show home page with active company for authenticated user" do
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
end
