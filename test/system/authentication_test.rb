require "application_system_test_case"

class AuthenticationTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
  end

  test "full sign-up flow: create account and land on home page" do
    visit new_registration_url

    fill_in "Email address", with: "brand_new@example.com"
    fill_in "Password", with: "securepassword123", match: :prefer_exact
    fill_in "Confirm password", with: "securepassword123"
    click_on "Create account"

    assert_current_path root_path
    assert_text "Welcome to Director"
    assert_text "brand_new@example.com"
  end

  test "sign-up with validation errors shows error messages" do
    visit new_registration_url

    # Use an email that already exists to trigger server-side uniqueness validation
    fill_in "Email address", with: @user.email_address
    fill_in "Password", with: "securepassword123", match: :prefer_exact
    fill_in "Confirm password", with: "securepassword123"
    click_on "Create account"

    assert_text "already been taken"
  end

  test "login and logout flow" do
    visit new_session_url

    fill_in "Email address", with: @user.email_address
    fill_in "Password", with: "password"
    click_on "Sign in"

    assert_current_path root_path
    assert_text @user.email_address

    click_on "Log out"

    assert_current_path new_session_path
  end

  test "login with wrong password shows error" do
    visit new_session_url

    fill_in "Email address", with: @user.email_address
    fill_in "Password", with: "wrongpassword"
    click_on "Sign in"

    assert_text "Try another email address or password."
  end

  test "session persists across page navigation" do
    visit new_session_url
    fill_in "Email address", with: @user.email_address
    fill_in "Password", with: "password"
    click_on "Sign in"

    click_on "Settings"
    assert_current_path settings_path

    click_on "Director"
    assert_current_path root_path
    assert_text @user.email_address
  end

  test "password reset request flow" do
    visit new_session_url
    click_on "Forgot password?"

    fill_in "Email address", with: @user.email_address
    click_on "Send reset instructions"

    assert_text "reset"
  end

  test "account settings: update email" do
    visit new_session_url
    fill_in "Email address", with: @user.email_address
    fill_in "Password", with: "password"
    click_on "Sign in"

    click_on "Settings"

    fill_in "Email address", with: "newemail@example.com"
    fill_in "Current password (required to save changes)", with: "password"
    click_on "Save changes"

    assert_text "updated"
    assert_text "newemail@example.com"
  end

  test "account settings: update password" do
    visit new_session_url
    fill_in "Email address", with: @user.email_address
    fill_in "Password", with: "password"
    click_on "Sign in"

    click_on "Settings"

    fill_in "New password", with: "brandnewpassword789"
    fill_in "Confirm new password", with: "brandnewpassword789"
    fill_in "Current password (required to save changes)", with: "password"
    click_on "Save changes"

    assert_text "updated"

    click_on "Log out"
    fill_in "Email address", with: @user.email_address
    fill_in "Password", with: "brandnewpassword789"
    click_on "Sign in"

    assert_text @user.email_address
  end

  test "account settings: reject changes with wrong current password" do
    visit new_session_url
    fill_in "Email address", with: @user.email_address
    fill_in "Password", with: "password"
    click_on "Sign in"

    click_on "Settings"

    fill_in "Email address", with: "hacker@example.com"
    fill_in "Current password (required to save changes)", with: "wrongpassword"
    click_on "Save changes"

    assert_text "incorrect"
  end

  test "unauthenticated user is redirected to login" do
    visit root_url
    assert_current_path new_session_path
  end

  test "navigation shows sign up and log in links when logged out" do
    visit new_session_url
    assert_text "Sign up"
    assert_text "Log in"
  end
end
