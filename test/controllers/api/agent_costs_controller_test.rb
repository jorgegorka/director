require "test_helper"

class Api::AgentCostsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @agent = agents(:http_agent)
    @task = tasks(:fix_login_bug)
    @auth_headers = { "Authorization" => "Bearer #{@agent.api_token}" }
    # Ensure agent has a budget for enforcement tests
    @agent.update_columns(budget_cents: 100000, budget_period_start: Date.current.beginning_of_month)
    # Clear existing notifications
    Notification.where(notifiable: @agent).delete_all
  end

  # --- Success ---

  test "reports cost for assigned task" do
    post cost_api_agent_task_url(@task), params: { cost_cents: 500 }, headers: @auth_headers, as: :json
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "ok", json["status"]
    assert_equal 500, json["cost_cents"]
  end

  test "accumulates cost on subsequent reports" do
    original_cost = @task.cost_cents || 0
    post cost_api_agent_task_url(@task), params: { cost_cents: 300 }, headers: @auth_headers, as: :json
    assert_response :success
    post cost_api_agent_task_url(@task), params: { cost_cents: 200 }, headers: @auth_headers, as: :json
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal original_cost + 500, json["total_cost_cents"]
  end

  test "returns budget summary in response" do
    post cost_api_agent_task_url(@task), params: { cost_cents: 100 }, headers: @auth_headers, as: :json
    assert_response :success
    json = JSON.parse(response.body)
    assert json["agent_budget"].present?
    assert json["agent_budget"]["budget_cents"].present?
    assert json["agent_budget"]["spent_cents"].present?
    assert json["agent_budget"]["remaining_cents"].present?
  end

  test "records audit event for cost" do
    assert_difference -> { AuditEvent.where(action: "cost_recorded").count } do
      post cost_api_agent_task_url(@task), params: { cost_cents: 500 }, headers: @auth_headers, as: :json
    end
    audit = AuditEvent.where(action: "cost_recorded").last
    assert_equal 500, audit.metadata["cost_cents"]
    assert_equal @agent.name, audit.metadata["agent_name"]
  end

  # --- Budget enforcement ---

  test "pauses agent when cost exhausts budget" do
    @agent.update_columns(budget_cents: 1, status: Agent.statuses[:idle])
    post cost_api_agent_task_url(@task), params: { cost_cents: 500 }, headers: @auth_headers, as: :json
    assert_response :success
    @agent.reload
    assert @agent.paused?
    assert_match /Budget exhausted/, @agent.pause_reason
  end

  test "returns 403 when agent is budget-paused" do
    @agent.update_columns(status: Agent.statuses[:paused], pause_reason: "Budget exhausted: test")
    post cost_api_agent_task_url(@task), params: { cost_cents: 100 }, headers: @auth_headers, as: :json
    assert_response :forbidden
    json = JSON.parse(response.body)
    assert_match /budget exhaustion/, json["error"]
  end

  # --- Validation ---

  test "returns 404 for non-existent task" do
    post cost_api_agent_task_url(id: 999999), params: { cost_cents: 500 }, headers: @auth_headers, as: :json
    assert_response :not_found
  end

  test "returns 403 for task not assigned to this agent" do
    other_task = tasks(:design_homepage)  # assigned to claude_agent, not http_agent
    post cost_api_agent_task_url(other_task), params: { cost_cents: 500 }, headers: @auth_headers, as: :json
    assert_response :forbidden
    json = JSON.parse(response.body)
    assert_match /not assigned/, json["error"]
  end

  test "returns 422 for negative cost_cents" do
    post cost_api_agent_task_url(@task), params: { cost_cents: -100 }, headers: @auth_headers, as: :json
    assert_response :unprocessable_entity
  end

  test "returns 401 without authentication" do
    post cost_api_agent_task_url(@task), params: { cost_cents: 500 }, as: :json
    assert_response :unauthorized
  end

  test "returns 401 with invalid token" do
    post cost_api_agent_task_url(@task), params: { cost_cents: 500 },
         headers: { "Authorization" => "Bearer invalid_token" }, as: :json
    assert_response :unauthorized
  end

  # --- Cross-company isolation ---

  test "returns 404 for task in different company" do
    widgets_task = tasks(:widgets_task)
    post cost_api_agent_task_url(widgets_task), params: { cost_cents: 500 }, headers: @auth_headers, as: :json
    assert_response :not_found
  end
end
