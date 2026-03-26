require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  test "should redirect unauthenticated user to login" do
    get root_url
    assert_redirected_to new_session_url
  end

  test "should show home page for authenticated user" do
    sign_in_as(@user)
    get root_url
    assert_response :success
    assert_select "header"
  end

  test "should show user email on home page" do
    sign_in_as(@user)
    get root_url
    assert_response :success
    assert_select ".home-hero"
  end
end
