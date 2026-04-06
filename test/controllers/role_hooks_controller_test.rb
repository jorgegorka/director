require "test_helper"

class RoleHooksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @project = projects(:acme)
    sign_in_as(@user)
    post project_switch_url(@project)
    @role = roles(:cto)
    @hook = role_hooks(:cto_validation_hook)
    @webhook_hook = role_hooks(:cto_webhook_hook)
    @disabled_hook = role_hooks(:disabled_hook)
    @widgets_role = roles(:widgets_lead)
  end

  # --- Index ---

  test "should get index" do
    get role_role_hooks_url(@role)
    assert_response :success
    assert_select ".hook-card", minimum: 1
  end

  test "should show hooks for the specific role only" do
    get role_role_hooks_url(@role)
    assert_response :success
    assert_select ".hook-card__title", text: /Validation by Developer/
  end

  test "should show empty state when role has no hooks" do
    get role_role_hooks_url(roles(:process_role))
    assert_response :success
    assert_select ".hooks-page__empty"
  end

  test "should not get index for role in another project" do
    get role_role_hooks_url(@widgets_role)
    assert_redirected_to root_url
  end

  # --- Show ---

  test "should show hook" do
    get role_role_hook_url(@role, @hook)
    assert_response :success
    assert_select "h1", @hook.name
    assert_select ".hook-detail__config-row", minimum: 4
  end

  test "should show webhook hook with URL" do
    get role_role_hook_url(@role, @webhook_hook)
    assert_response :success
    assert_select "code", text: /hooks\.example\.com/
  end

  test "should not show hook from another role" do
    get role_role_hook_url(@role, @disabled_hook)
    assert_redirected_to root_url
  end

  test "should not show hook for role in another project" do
    get role_role_hook_url(@widgets_role, @hook)
    assert_redirected_to root_url
  end

  # --- New ---

  test "should get new hook form" do
    get new_role_role_hook_url(@role)
    assert_response :success
    assert_select "form"
    assert_select "select[name='role_hook[lifecycle_event]']"
    assert_select "select[name='role_hook[action_type]']"
  end

  # --- Create ---

  test "should create trigger_agent hook" do
    target_role = roles(:developer)
    assert_difference("RoleHook.count", 1) do
      post role_role_hooks_url(@role), params: {
        role_hook: {
          name: "New Validation Hook",
          lifecycle_event: "after_task_complete",
          action_type: "trigger_agent",
          enabled: true,
          position: 5,
          action_config: {
            target_role_id: target_role.id,
            prompt: "Please review."
          }
        }
      }
    end
    hook = RoleHook.order(:created_at).last
    assert_equal "New Validation Hook", hook.name
    assert_equal "after_task_complete", hook.lifecycle_event
    assert_equal "trigger_agent", hook.action_type
    assert_equal true, hook.enabled
    assert_equal 5, hook.position
    assert_equal target_role.id, hook.action_config["target_role_id"].to_i
    assert_equal "Please review.", hook.action_config["prompt"]
    assert_equal @role, hook.role
    assert_equal @project, hook.project
    assert_redirected_to role_role_hook_url(@role, hook)
  end

  test "should create webhook hook" do
    assert_difference("RoleHook.count", 1) do
      post role_role_hooks_url(@role), params: {
        role_hook: {
          name: "Slack Notify",
          lifecycle_event: "after_task_start",
          action_type: "webhook",
          enabled: true,
          position: 0,
          action_config: {
            url: "https://hooks.slack.com/services/test"
          }
        }
      }
    end
    hook = RoleHook.order(:created_at).last
    assert_equal "webhook", hook.action_type
    assert_equal "https://hooks.slack.com/services/test", hook.action_config["url"]
    assert_redirected_to role_role_hook_url(@role, hook)
  end

  test "should not create hook without lifecycle_event" do
    assert_no_difference("RoleHook.count") do
      post role_role_hooks_url(@role), params: {
        role_hook: {
          name: "Bad Hook",
          lifecycle_event: "",
          action_type: "webhook",
          action_config: { url: "https://example.com" }
        }
      }
    end
    assert_response :unprocessable_entity
  end

  test "should not create hook for role in another project" do
    assert_no_difference("RoleHook.count") do
      post role_role_hooks_url(@widgets_role), params: {
        role_hook: {
          name: "Hacked Hook",
          lifecycle_event: "after_task_complete",
          action_type: "webhook",
          action_config: { url: "https://evil.com" }
        }
      }
    end
    assert_redirected_to root_url
  end

  # --- Edit ---

  test "should get edit hook form" do
    get edit_role_role_hook_url(@role, @hook)
    assert_response :success
    assert_select "form"
  end

  # --- Update ---

  test "should update hook" do
    patch role_role_hook_url(@role, @hook), params: {
      role_hook: {
        name: "Updated Hook Name",
        enabled: false
      }
    }
    assert_redirected_to role_role_hook_url(@role, @hook)
    @hook.reload
    assert_equal "Updated Hook Name", @hook.name
    assert_equal false, @hook.enabled
  end

  test "should not update hook from another role" do
    patch role_role_hook_url(@role, @disabled_hook), params: {
      role_hook: { name: "Hacked" }
    }
    assert_redirected_to root_url
  end

  # --- Destroy ---

  test "should destroy hook" do
    assert_difference("RoleHook.count", -1) do
      delete role_role_hook_url(@role, @hook)
    end
    assert_redirected_to role_role_hooks_url(@role)
  end

  test "should not destroy hook from another role" do
    assert_no_difference("RoleHook.count") do
      delete role_role_hook_url(@role, @disabled_hook)
    end
    assert_redirected_to root_url
  end

  # --- Auth Guards ---

  test "should redirect unauthenticated user on index" do
    sign_out
    get role_role_hooks_url(@role)
    assert_redirected_to new_session_url
  end

  test "should redirect user without project on index" do
    user_without_project = User.create!(
      email_address: "nohooks@example.com",
      password: "password",
      password_confirmation: "password"
    )
    sign_in_as(user_without_project)
    get role_role_hooks_url(@role)
    assert_redirected_to new_project_url
  end
end
