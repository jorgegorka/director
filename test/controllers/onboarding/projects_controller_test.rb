require "test_helper"

class Onboarding::ProjectsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user_with_projects = users(:one)
    @fresh_user = User.create!(
      email_address: "fresh@example.com",
      password: "securepassword",
      password_confirmation: "securepassword"
    )
  end

  test "new shows project form for user without projects" do
    sign_in_as(@fresh_user)
    get new_onboarding_project_url
    assert_response :success
    assert_select "form"
    assert_select "input[name='project[name]']"
  end

  test "new redirects to root if user already has projects" do
    sign_in_as(@user_with_projects)
    get new_onboarding_project_url
    assert_redirected_to root_path
  end

  test "create creates project and membership then redirects to template step" do
    sign_in_as(@fresh_user)

    assert_difference [ "Project.count", "Membership.count" ], 1 do
      post onboarding_project_url, params: { project: { name: "My New Project", description: "Testing onboarding" } }
    end

    assert_redirected_to new_onboarding_template_url

    project = @fresh_user.projects.last
    assert_equal "My New Project", project.name
    assert_equal "Testing onboarding", project.description
    assert project.memberships.exists?(user: @fresh_user, role: :owner)
  end

  test "create renders form with errors on invalid input" do
    sign_in_as(@fresh_user)

    assert_no_difference "Project.count" do
      post onboarding_project_url, params: { project: { name: "" } }
    end

    assert_response :unprocessable_entity
  end

  test "create seeds default role categories and skills" do
    sign_in_as(@fresh_user)

    post onboarding_project_url, params: { project: { name: "Seeded Project" } }

    project = @fresh_user.projects.last
    assert project.role_categories.any?, "Should have seeded role categories"
    assert project.skills.any?, "Should have seeded skills"
  end

  test "requires authentication" do
    get new_onboarding_project_url
    assert_redirected_to new_session_url
  end
end
