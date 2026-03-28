require "test_helper"

class AgentRunsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @company = companies(:acme)
    sign_in_as(@user)
    post company_switch_url(@company)
    @agent = agents(:claude_agent)
  end

  # --- Index ---

  test "index lists agent runs" do
    get agent_agent_runs_url(@agent)
    assert_response :success
    assert_select "table"
  end

  test "index requires authentication" do
    sign_out
    get agent_agent_runs_url(@agent)
    assert_redirected_to new_session_url
  end

  test "index scopes to current company" do
    other_agent = agents(:widgets_agent)
    get agent_agent_runs_url(other_agent)
    assert_response :not_found
  end

  test "index shows empty state when no runs" do
    @agent.agent_runs.delete_all
    get agent_agent_runs_url(@agent)
    assert_response :success
    assert_select ".agent-runs__empty"
  end

  # --- Show ---

  test "show displays agent run details" do
    run = agent_runs(:completed_run)
    get agent_agent_run_url(@agent, run)
    assert_response :success
    assert_select ".agent-run-detail"
  end

  test "show includes output stream container" do
    run = agent_runs(:completed_run)
    get agent_agent_run_url(@agent, run)
    assert_response :success
    assert_select ".agent-run-output__stream"
  end

  test "show rejects run from different agent" do
    other_run = agent_runs(:running_run) # belongs to http_agent
    get agent_agent_run_url(@agent, other_run)
    assert_response :not_found
  end

  test "show displays log output for completed run" do
    run = agent_runs(:completed_run) # has log_output: "Task completed successfully"
    get agent_agent_run_url(@agent, run)
    assert_response :success
    assert_select ".agent-run-output__stream"
  end

  test "show displays error message for failed run" do
    run = @agent.agent_runs.create!(
      company: @company,
      status: :failed,
      trigger_type: "task_assigned",
      error_message: "Something went wrong",
      completed_at: Time.current
    )
    get agent_agent_run_url(@agent, run)
    assert_response :success
    assert_select ".agent-run-detail__kv-row--error"
  end
end
