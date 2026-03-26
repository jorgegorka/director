require "test_helper"

class SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test "should show settings page" do
    get settings_url
    assert_response :success
    assert_select "form"
  end

  test "should redirect unauthenticated user to login" do
    sign_out
    get settings_url
    assert_redirected_to new_session_url
  end

  test "should update email with correct current password" do
    patch settings_url, params: {
      current_password: "password",
      user: { email_address: "updated@example.com" }
    }
    assert_redirected_to settings_url
    @user.reload
    assert_equal "updated@example.com", @user.email_address
  end

  test "should update password with correct current password" do
    patch settings_url, params: {
      current_password: "password",
      user: {
        password: "newpassword456",
        password_confirmation: "newpassword456"
      }
    }
    assert_redirected_to settings_url
    @user.reload
    assert @user.authenticate("newpassword456")
  end

  test "should reject update with wrong current password" do
    patch settings_url, params: {
      current_password: "wrongpassword",
      user: { email_address: "hacker@example.com" }
    }
    assert_response :unprocessable_entity
    @user.reload
    assert_not_equal "hacker@example.com", @user.email_address
  end

  test "should reject update with mismatched password confirmation" do
    patch settings_url, params: {
      current_password: "password",
      user: {
        password: "newpassword456",
        password_confirmation: "doesnotmatch"
      }
    }
    assert_response :unprocessable_entity
  end

  test "should not change password when password fields are blank" do
    original_digest = @user.password_digest
    patch settings_url, params: {
      current_password: "password",
      user: { email_address: "onlyemail@example.com" }
    }
    assert_redirected_to settings_url
    @user.reload
    assert_equal "onlyemail@example.com", @user.email_address
    assert_equal original_digest, @user.password_digest
  end
end
