require "test_helper"

class AgentHooksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @company = companies(:acme)
    sign_in_as(@user)
    post company_switch_url(@company)
    @agent = agents(:claude_agent)
    @hook = agent_hooks(:claude_validation_hook)
    @webhook_hook = agent_hooks(:claude_webhook_hook)
    @disabled_hook = agent_hooks(:disabled_hook)
    @widgets_agent = agents(:widgets_agent)
  end

  # --- Index ---

  test "should get index" do
    get agent_agent_hooks_url(@agent)
    assert_response :success
    assert_select ".hook-card", minimum: 1
  end

  test "should show hooks for the specific agent only" do
    get agent_agent_hooks_url(@agent)
    assert_response :success
    # claude_agent has hooks; disabled_hook belongs to http_agent
    assert_select ".hook-card__title", text: /Validation by API Bot/
  end

  test "should show empty state when agent has no hooks" do
    # process_agent has no hooks in fixtures
    get agent_agent_hooks_url(agents(:process_agent))
    assert_response :success
    assert_select ".hooks-page__empty"
  end

  test "should not get index for agent in another company" do
    get agent_agent_hooks_url(@widgets_agent)
    assert_response :not_found
  end

  # --- Show ---

  test "should show hook" do
    get agent_agent_hook_url(@agent, @hook)
    assert_response :success
    assert_select "h1", @hook.name
    assert_select ".hook-detail__config-row", minimum: 4
  end

  test "should show webhook hook with URL" do
    get agent_agent_hook_url(@agent, @webhook_hook)
    assert_response :success
    assert_select "code", text: /hooks\.example\.com/
  end

  test "should not show hook from another agent" do
    # disabled_hook belongs to http_agent, not claude_agent
    get agent_agent_hook_url(@agent, @disabled_hook)
    assert_response :not_found
  end

  test "should not show hook for agent in another company" do
    get agent_agent_hook_url(@widgets_agent, @hook)
    assert_response :not_found
  end

  # --- New ---

  test "should get new hook form" do
    get new_agent_agent_hook_url(@agent)
    assert_response :success
    assert_select "form"
    assert_select "select[name='agent_hook[lifecycle_event]']"
    assert_select "select[name='agent_hook[action_type]']"
  end

  # --- Create ---

  test "should create trigger_agent hook" do
    target_agent = agents(:http_agent)
    assert_difference("AgentHook.count", 1) do
      post agent_agent_hooks_url(@agent), params: {
        agent_hook: {
          name: "New Validation Hook",
          lifecycle_event: "after_task_complete",
          action_type: "trigger_agent",
          enabled: true,
          position: 5,
          action_config: {
            target_agent_id: target_agent.id,
            prompt: "Please review."
          }
        }
      }
    end
    hook = AgentHook.order(:created_at).last
    assert_equal "New Validation Hook", hook.name
    assert_equal "after_task_complete", hook.lifecycle_event
    assert_equal "trigger_agent", hook.action_type
    assert_equal true, hook.enabled
    assert_equal 5, hook.position
    assert_equal target_agent.id, hook.action_config["target_agent_id"].to_i
    assert_equal "Please review.", hook.action_config["prompt"]
    assert_equal @agent, hook.agent
    assert_equal @company, hook.company
    assert_redirected_to agent_agent_hook_url(@agent, hook)
  end

  test "should create webhook hook" do
    assert_difference("AgentHook.count", 1) do
      post agent_agent_hooks_url(@agent), params: {
        agent_hook: {
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
    hook = AgentHook.order(:created_at).last
    assert_equal "webhook", hook.action_type
    assert_equal "https://hooks.slack.com/services/test", hook.action_config["url"]
    assert_redirected_to agent_agent_hook_url(@agent, hook)
  end

  test "should not create hook without lifecycle_event" do
    assert_no_difference("AgentHook.count") do
      post agent_agent_hooks_url(@agent), params: {
        agent_hook: {
          name: "Bad Hook",
          lifecycle_event: "",
          action_type: "webhook",
          action_config: { url: "https://example.com" }
        }
      }
    end
    assert_response :unprocessable_entity
  end

  test "should not create hook with invalid lifecycle_event" do
    assert_no_difference("AgentHook.count") do
      post agent_agent_hooks_url(@agent), params: {
        agent_hook: {
          name: "Bad Hook",
          lifecycle_event: "invalid_event",
          action_type: "webhook",
          action_config: { url: "https://example.com" }
        }
      }
    end
    assert_response :unprocessable_entity
  end

  test "should not create hook for agent in another company" do
    assert_no_difference("AgentHook.count") do
      post agent_agent_hooks_url(@widgets_agent), params: {
        agent_hook: {
          name: "Hacked Hook",
          lifecycle_event: "after_task_complete",
          action_type: "webhook",
          action_config: { url: "https://evil.com" }
        }
      }
    end
    assert_response :not_found
  end

  # --- Edit ---

  test "should get edit hook form" do
    get edit_agent_agent_hook_url(@agent, @hook)
    assert_response :success
    assert_select "form"
  end

  # --- Update ---

  test "should update hook" do
    patch agent_agent_hook_url(@agent, @hook), params: {
      agent_hook: {
        name: "Updated Hook Name",
        enabled: false
      }
    }
    assert_redirected_to agent_agent_hook_url(@agent, @hook)
    @hook.reload
    assert_equal "Updated Hook Name", @hook.name
    assert_equal false, @hook.enabled
  end

  test "should update hook lifecycle_event" do
    patch agent_agent_hook_url(@agent, @hook), params: {
      agent_hook: {
        lifecycle_event: "after_task_start"
      }
    }
    assert_redirected_to agent_agent_hook_url(@agent, @hook)
    @hook.reload
    assert_equal "after_task_start", @hook.lifecycle_event
  end

  test "should not update hook with invalid lifecycle_event" do
    patch agent_agent_hook_url(@agent, @hook), params: {
      agent_hook: {
        lifecycle_event: "invalid_event"
      }
    }
    assert_response :unprocessable_entity
  end

  test "should not update hook from another agent" do
    # disabled_hook belongs to http_agent
    patch agent_agent_hook_url(@agent, @disabled_hook), params: {
      agent_hook: { name: "Hacked" }
    }
    assert_response :not_found
  end

  test "should not update hook for agent in another company" do
    patch agent_agent_hook_url(@widgets_agent, @hook), params: {
      agent_hook: { name: "Hacked" }
    }
    assert_response :not_found
  end

  # --- Destroy ---

  test "should destroy hook" do
    assert_difference("AgentHook.count", -1) do
      delete agent_agent_hook_url(@agent, @hook)
    end
    assert_redirected_to agent_agent_hooks_url(@agent)
  end

  test "should not destroy hook from another agent" do
    assert_no_difference("AgentHook.count") do
      delete agent_agent_hook_url(@agent, @disabled_hook)
    end
    assert_response :not_found
  end

  test "should not destroy hook for agent in another company" do
    assert_no_difference("AgentHook.count") do
      delete agent_agent_hook_url(@widgets_agent, @hook)
    end
    assert_response :not_found
  end

  # --- Auth Guards ---

  test "should redirect unauthenticated user on index" do
    sign_out
    get agent_agent_hooks_url(@agent)
    assert_redirected_to new_session_url
  end

  test "should redirect unauthenticated user on create" do
    sign_out
    post agent_agent_hooks_url(@agent), params: {
      agent_hook: { name: "Test", lifecycle_event: "after_task_complete", action_type: "webhook" }
    }
    assert_redirected_to new_session_url
  end

  test "should redirect user without company on index" do
    user_without_company = User.create!(
      email_address: "nohooks@example.com",
      password: "password",
      password_confirmation: "password"
    )
    sign_in_as(user_without_company)
    get agent_agent_hooks_url(@agent)
    assert_redirected_to new_company_url
  end
end
