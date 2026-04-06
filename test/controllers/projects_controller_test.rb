require "test_helper"

class ProjectsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test "should get index with user's projects" do
    get projects_url
    assert_response :success
    assert_select ".project-card", count: 2  # user :one belongs to acme + widgets
  end

  test "should redirect unauthenticated user" do
    sign_out
    get projects_url
    assert_redirected_to new_session_url
  end

  test "should get new project form" do
    get new_project_url
    assert_response :success
    assert_select "form"
  end

  test "should create project and assign owner role" do
    assert_difference([ "Project.count", "Membership.count" ], 1) do
      post projects_url, params: { project: { name: "New AI Corp" } }
    end
    project = Project.order(:created_at).last
    assert_equal "New AI Corp", project.name
    membership = project.memberships.find_by(user: @user)
    assert membership.owner?
    assert_redirected_to root_url
  end

  test "should set session project_id after creation" do
    post projects_url, params: { project: { name: "Session Test Corp" } }
    follow_redirect! # root → pages#home redirects authenticated users to dashboard
    follow_redirect!
    assert_response :success
    # The dashboard should show the new project name
    assert_select "h1", "Session Test Corp"
  end

  test "should not create project with blank name" do
    assert_no_difference("Project.count") do
      post projects_url, params: { project: { name: "" } }
    end
    assert_response :unprocessable_entity
  end

  test "should get edit project form" do
    project = projects(:acme)
    get edit_project_url(project)
    assert_response :success
    assert_select "form"
  end

  test "should update project max_concurrent_agents" do
    project = projects(:acme)
    patch project_url(project), params: { project: { max_concurrent_agents: 3 } }
    assert_redirected_to projects_url
    assert_equal 3, project.reload.max_concurrent_agents
  end

  test "should not update project with invalid max_concurrent_agents" do
    project = projects(:acme)
    patch project_url(project), params: { project: { max_concurrent_agents: -1 } }
    assert_response :unprocessable_entity
  end

  test "should update project name" do
    project = projects(:acme)
    patch project_url(project), params: { project: { name: "Renamed Corp" } }
    assert_redirected_to projects_url
    assert_equal "Renamed Corp", project.reload.name
  end
end
