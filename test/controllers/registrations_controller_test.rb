require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "should get new registration form" do
    get new_registration_url
    assert_response :success
    assert_select "form"
  end

  test "should create user with valid params" do
    assert_difference("User.count", 1) do
      post registration_url, params: {
        user: {
          email_address: "new@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end
    # New users are redirected to root → dashboard → project creation (no projects yet)
    assert_redirected_to root_url
    follow_redirect!
    assert_redirected_to dashboard_url
    follow_redirect!
    assert_redirected_to new_onboarding_project_url
  end

  test "should not create user with invalid email" do
    assert_no_difference("User.count") do
      post registration_url, params: {
        user: {
          email_address: "",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end
    assert_response :unprocessable_entity
  end

  test "should not create user with mismatched passwords" do
    assert_no_difference("User.count") do
      post registration_url, params: {
        user: {
          email_address: "new@example.com",
          password: "password123",
          password_confirmation: "different"
        }
      }
    end
    assert_response :unprocessable_entity
  end

  test "should not create user with duplicate email" do
    User.create!(email_address: "taken@example.com", password: "password123", password_confirmation: "password123")
    assert_no_difference("User.count") do
      post registration_url, params: {
        user: {
          email_address: "taken@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end
    assert_response :unprocessable_entity
  end

  test "should automatically log in after registration" do
    post registration_url, params: {
      user: {
        email_address: "auto@example.com",
        password: "password123",
        password_confirmation: "password123"
      }
    }
    # After redirect to root, new user is bounced through dashboard to project creation
    follow_redirect!
    follow_redirect!
    assert_redirected_to new_onboarding_project_url
  end
end
