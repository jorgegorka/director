require "test_helper"

class TaskEscalationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @company = companies(:acme)
    sign_in_as(@user)
    post company_switch_url(@company)

    @claude_agent = agents(:claude_agent)
    @http_agent = agents(:http_agent)
    @widgets_agent = agents(:widgets_agent)

    # fix_login_bug is assigned to http_agent (developer role)
    # developer role parent is CTO which has claude_agent -- escalates to claude_agent
    @task = tasks(:fix_login_bug)

    # design_homepage is assigned to claude_agent (CTO role)
    # CTO parent is CEO which has no agent -- escalation fails
    @cto_task = tasks(:design_homepage)

    @unassigned_task = tasks(:write_tests)
    @widgets_task = tasks(:widgets_task)
  end

  # ==========================================================================
  # Human-initiated escalation tests (session auth)
  # ==========================================================================

  test "human user can escalate task to manager agent" do
    assert_difference("AuditEvent.count", 1) do
      post escalate_task_url(@task)
    end

    assert_redirected_to task_path(@task)
    assert_equal "Task escalated to #{@claude_agent.name}.", flash[:notice]

    @task.reload
    assert_equal @claude_agent, @task.assignee

    event = AuditEvent.where(action: "escalated").last
    assert_equal "escalated", event.action
    assert_equal "User", event.actor_type
    assert_equal @user.id, event.actor_id
    assert_equal @http_agent.id, event.metadata["from_agent_id"]
    assert_equal @claude_agent.id, event.metadata["to_agent_id"]
  end

  test "human user cannot escalate when no manager has agent" do
    original_assignee = @cto_task.assignee

    post escalate_task_url(@cto_task)

    assert_redirected_to task_path(@cto_task)
    assert_match "Cannot escalate", flash[:alert]

    @cto_task.reload
    assert_equal original_assignee, @cto_task.assignee
  end

  test "human user cannot escalate unassigned task" do
    post escalate_task_url(@unassigned_task)

    assert_redirected_to task_path(@unassigned_task)
    assert_match "Cannot escalate", flash[:alert]

    @unassigned_task.reload
    assert_nil @unassigned_task.assignee
  end

  test "human user escalation records reason in audit" do
    post escalate_task_url(@task), params: { reason: "Needs manager attention" }

    event = AuditEvent.where(action: "escalated").last
    assert_equal "Needs manager attention", event.metadata["reason"]
  end

  test "human user cannot escalate task from another company" do
    post escalate_task_url(@widgets_task)

    assert_response :not_found
  end

  test "should redirect unauthenticated human user" do
    sign_out

    post escalate_task_url(@task)

    assert_redirected_to new_session_path
  end

  # ==========================================================================
  # Agent-initiated escalation tests (Bearer token auth)
  # ==========================================================================

  test "agent can escalate task via API with Bearer token" do
    sign_out

    assert_difference("AuditEvent.count", 1) do
      post escalate_task_url(@task, format: :json),
           headers: { "Authorization" => "Bearer #{@http_agent.api_token}" }
    end

    assert_response :ok
    json = response.parsed_body
    assert_equal "ok", json["status"]

    @task.reload
    assert_equal @claude_agent, @task.assignee

    event = AuditEvent.where(action: "escalated").last
    assert_equal "Agent", event.actor_type
    assert_equal @http_agent.id, event.actor_id
  end

  test "agent API escalation returns JSON error when no manager agent exists" do
    sign_out
    original_assignee = @cto_task.assignee

    post escalate_task_url(@cto_task, format: :json),
         headers: { "Authorization" => "Bearer #{@claude_agent.api_token}" }

    assert_response :unprocessable_entity
    json = response.parsed_body
    assert json["error"].present?

    @cto_task.reload
    assert_equal original_assignee, @cto_task.assignee
  end

  test "agent API escalation returns 401 for invalid token" do
    sign_out

    post escalate_task_url(@task, format: :json),
         headers: { "Authorization" => "Bearer invalid_token_xyz" }

    assert_response :unauthorized
    json = response.parsed_body
    assert_equal "Unauthorized", json["error"]
  end

  test "agent API cannot escalate task from another company" do
    sign_out

    post escalate_task_url(@task, format: :json),
         headers: { "Authorization" => "Bearer #{@widgets_agent.api_token}" }

    assert_response :not_found
    json = response.parsed_body
    assert_equal "Not found", json["error"]
  end
end
