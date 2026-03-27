require "test_helper"

class TaskDelegationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @company = companies(:acme)
    sign_in_as(@user)
    post company_switch_url(@company)

    @claude_agent = agents(:claude_agent)
    @http_agent = agents(:http_agent)
    @process_agent = agents(:process_agent)
    @widgets_agent = agents(:widgets_agent)

    # design_homepage is assigned to claude_agent (CTO role)
    # developer role has http_agent as subordinate -- can delegate to http_agent
    @task = tasks(:design_homepage)
    @widgets_task = tasks(:widgets_task)
    @unassigned_task = tasks(:write_tests)
  end

  # ==========================================================================
  # Human-initiated delegation tests (session auth)
  # ==========================================================================

  test "human user can delegate task to subordinate agent" do
    assert_difference("AuditEvent.count", 1) do
      post delegate_task_url(@task), params: { agent_id: @http_agent.id }
    end

    assert_redirected_to task_path(@task)
    assert_equal "Task delegated to #{@http_agent.name}.", flash[:notice]

    @task.reload
    assert_equal @http_agent, @task.assignee

    event = AuditEvent.where(action: "delegated").last
    assert_equal "delegated", event.action
    assert_equal "User", event.actor_type
    assert_equal @user.id, event.actor_id
    assert_equal @claude_agent.id, event.metadata["from_agent_id"]
    assert_equal @http_agent.id, event.metadata["to_agent_id"]
  end

  test "human user cannot delegate to agent not in subordinate role" do
    original_assignee = @task.assignee

    post delegate_task_url(@task), params: { agent_id: @process_agent.id }

    assert_redirected_to task_path(@task)
    assert_match "Cannot delegate", flash[:alert]

    @task.reload
    assert_equal original_assignee, @task.assignee
  end

  test "human user cannot delegate unassigned task" do
    post delegate_task_url(@unassigned_task), params: { agent_id: @http_agent.id }

    assert_redirected_to task_path(@unassigned_task)
    assert_match "Cannot delegate", flash[:alert]

    @unassigned_task.reload
    assert_nil @unassigned_task.assignee
  end

  test "human user delegation records reason in audit metadata" do
    post delegate_task_url(@task), params: { agent_id: @http_agent.id, reason: "Delegating to senior developer" }

    event = AuditEvent.where(action: "delegated").last
    assert_equal "Delegating to senior developer", event.metadata["reason"]
  end

  test "human user cannot delegate task from another company" do
    post delegate_task_url(@widgets_task), params: { agent_id: @http_agent.id }

    assert_response :not_found
  end

  test "should redirect unauthenticated human user" do
    sign_out

    post delegate_task_url(@task), params: { agent_id: @http_agent.id }

    assert_redirected_to new_session_path
  end

  # ==========================================================================
  # Agent-initiated delegation tests (Bearer token auth)
  # ==========================================================================

  test "agent can delegate task via API with Bearer token" do
    sign_out

    assert_difference("AuditEvent.count", 1) do
      post delegate_task_url(@task, format: :json),
           params: { agent_id: @http_agent.id },
           headers: { "Authorization" => "Bearer #{@claude_agent.api_token}" }
    end

    assert_response :ok
    json = response.parsed_body
    assert_equal "ok", json["status"]
    assert_equal @task.id, json["task_id"]

    @task.reload
    assert_equal @http_agent, @task.assignee

    event = AuditEvent.where(action: "delegated").last
    assert_equal "Agent", event.actor_type
    assert_equal @claude_agent.id, event.actor_id
  end

  test "agent API delegation returns JSON error for invalid target" do
    sign_out
    original_assignee = @task.assignee

    post delegate_task_url(@task, format: :json),
         params: { agent_id: @process_agent.id },
         headers: { "Authorization" => "Bearer #{@claude_agent.api_token}" }

    assert_response :unprocessable_entity
    json = response.parsed_body
    assert json["error"].present?

    @task.reload
    assert_equal original_assignee, @task.assignee
  end

  test "agent API returns 401 for invalid Bearer token" do
    sign_out

    post delegate_task_url(@task, format: :json),
         params: { agent_id: @http_agent.id },
         headers: { "Authorization" => "Bearer invalid_token_xyz" }

    assert_response :unauthorized
    json = response.parsed_body
    assert_equal "Unauthorized", json["error"]
  end

  test "agent API returns 401 for missing Authorization header" do
    sign_out

    post delegate_task_url(@task, format: :json),
         params: { agent_id: @http_agent.id }

    assert_response :unauthorized
    json = response.parsed_body
    assert_equal "Unauthorized", json["error"]
  end

  test "agent API sets Current.company from agent company" do
    sign_out

    post delegate_task_url(@task, format: :json),
         params: { agent_id: @http_agent.id },
         headers: { "Authorization" => "Bearer #{@claude_agent.api_token}" }

    assert_response :ok
    @task.reload
    assert_equal @http_agent, @task.assignee
  end

  test "agent API cannot delegate task from another company" do
    sign_out

    post delegate_task_url(@task, format: :json),
         params: { agent_id: @http_agent.id },
         headers: { "Authorization" => "Bearer #{@widgets_agent.api_token}" }

    assert_response :not_found
    json = response.parsed_body
    assert_equal "Not found", json["error"]
  end
end
