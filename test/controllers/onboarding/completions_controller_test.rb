require "test_helper"

class Onboarding::CompletionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @fresh_user = User.create!(
      email_address: "fresh@example.com",
      password: "securepassword",
      password_confirmation: "securepassword"
    )
    sign_in_as(@fresh_user)

    # Walk through steps 1-2 (template)
    post onboarding_project_url, params: { project: { name: "Completion Test" } }
    @project = @fresh_user.projects.last
  end

  test "new shows summary after template flow" do
    post onboarding_template_url, params: { template_key: "engineering" }
    post onboarding_adapter_url, params: { adapter_type: "claude_local", adapter_config: { model: "claude-sonnet-4-20250514" } }

    get new_onboarding_completion_url
    assert_response :success
    assert_select ".onboarding__summary-card"
    assert_select ".hierarchy-tree"
  end

  test "new shows summary for scratch flow" do
    post onboarding_template_url, params: { template_key: "scratch" }

    get new_onboarding_completion_url
    assert_response :success
    assert_select ".onboarding__summary-card"
  end

  test "create clears onboarding state and redirects to org chart" do
    post onboarding_template_url, params: { template_key: "scratch" }

    post onboarding_completion_url
    assert_redirected_to roles_url
    follow_redirect!
    assert_select ".flash--notice", text: /ready/i
  end

  test "full wizard flow with template" do
    # Step 2: choose template
    post onboarding_template_url, params: { template_key: "engineering" }
    assert_redirected_to new_onboarding_adapter_url

    # Step 3: configure adapter
    post onboarding_adapter_url, params: {
      adapter_type: "claude_local",
      working_directory: "/tmp/test",
      adapter_config: { model: "claude-sonnet-4-20250514" }
    }
    assert_redirected_to new_onboarding_completion_url

    # Step 4: review and finish
    get new_onboarding_completion_url
    assert_response :success

    post onboarding_completion_url
    assert_redirected_to roles_url

    # Verify project state
    assert @project.roles.any?, "Template roles should exist"
    assert @project.roles.all? { |r| r.adapter_type == "claude_local" }, "All roles should have adapter configured"
  end

  test "full wizard flow from scratch" do
    # Step 2: start from scratch
    post onboarding_template_url, params: { template_key: "scratch" }
    assert_redirected_to new_onboarding_completion_url

    # Step 4: review and finish (step 3 skipped)
    post onboarding_completion_url
    assert_redirected_to roles_url

    assert_equal 0, @project.roles.count
  end
end
