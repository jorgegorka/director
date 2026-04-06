require "test_helper"

class Projects::SwitchesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test "should switch active project" do
    post project_switch_url(projects(:widgets))
    assert_redirected_to root_url
    follow_redirect! # root → pages#home redirects authenticated users to dashboard
    follow_redirect!
    assert_response :success
    assert_select "h1", "Widget Factory"
  end

  test "should not switch to project user does not belong to" do
    other_project = Project.create!(name: "Secret Corp")
    post project_switch_url(other_project)
    assert_redirected_to projects_url
  end

  test "should redirect unauthenticated user" do
    sign_out
    post project_switch_url(projects(:acme))
    assert_redirected_to new_session_url
  end
end
