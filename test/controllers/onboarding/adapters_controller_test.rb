require "test_helper"

class Onboarding::AdaptersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @fresh_user = User.create!(
      email_address: "fresh@example.com",
      password: "securepassword",
      password_confirmation: "securepassword"
    )
    sign_in_as(@fresh_user)

    # Walk through steps 1-2
    post onboarding_project_url, params: { project: { name: "Adapter Test" } }
    @project = @fresh_user.projects.last
    post onboarding_template_url, params: { template_key: "engineering" }
  end

  test "new shows adapter configuration form" do
    get new_onboarding_adapter_url
    assert_response :success
    assert_select "select[name='adapter_type']"
  end

  test "create configures adapter on all roles and redirects to completion" do
    post onboarding_adapter_url, params: {
      adapter_type: "claude_local",
      working_directory: "/tmp/test-project",
      adapter_config: { model: "claude-sonnet-4-20250514", provider: "anthropic" }
    }

    assert_redirected_to new_onboarding_completion_url

    @project.roles.reload.each do |role|
      assert_equal "claude_local", role.adapter_type
      assert_equal "/tmp/test-project", role.working_directory
    end
  end

  test "redirects to project step if no onboarding project" do
    fresh_user2 = User.create!(
      email_address: "fresh2@example.com",
      password: "securepassword",
      password_confirmation: "securepassword"
    )
    sign_in_as(fresh_user2)

    get new_onboarding_adapter_url
    assert_redirected_to new_onboarding_project_url
  end
end
