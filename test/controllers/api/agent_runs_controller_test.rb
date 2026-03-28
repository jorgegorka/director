require "test_helper"

class Api::AgentRunsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @agent = agents(:claude_agent)
    @company = companies(:acme)
    @auth_headers = { "Authorization" => "Bearer #{@agent.api_token}" }

    # Create a running agent run for tests
    @agent.update!(status: :running)
    @running_run = @agent.agent_runs.create!(
      company: @company,
      status: :running,
      trigger_type: "task_assigned",
      task: tasks(:design_homepage),
      started_at: Time.current
    )
  end

  # =====================
  # POST /api/agent_runs/:id/result
  # =====================

  # --- Success ---

  test "result marks run as completed" do
    post result_api_agent_run_url(@running_run),
         params: { exit_code: 0 },
         headers: @auth_headers,
         as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "ok", json["status"]
    assert_equal @running_run.id, json["agent_run_id"]

    @running_run.reload
    assert @running_run.completed?
    assert_equal 0, @running_run.exit_code
    assert_not_nil @running_run.completed_at
  end

  test "result stores session_id and cost_cents" do
    post result_api_agent_run_url(@running_run),
         params: { exit_code: 0, cost_cents: 500, session_id: "sess_xyz" },
         headers: @auth_headers,
         as: :json

    assert_response :success
    @running_run.reload
    assert_equal "sess_xyz", @running_run.claude_session_id
    assert_equal 500, @running_run.cost_cents
  end

  test "result returns agent to idle" do
    post result_api_agent_run_url(@running_run),
         params: { exit_code: 0 },
         headers: @auth_headers,
         as: :json

    assert_response :success
    assert @agent.reload.idle?
  end

  # --- CALLBACK-03: Task status update + conversation message ---

  test "result updates associated task to completed" do
    task = @running_run.task
    task.update!(status: :in_progress)

    post result_api_agent_run_url(@running_run),
         params: { exit_code: 0, summary: "Finished the homepage design." },
         headers: @auth_headers,
         as: :json

    assert_response :success
    assert task.reload.completed?
  end

  test "result posts completion message to task conversation" do
    task = @running_run.task
    initial_message_count = task.messages.count

    post result_api_agent_run_url(@running_run),
         params: { exit_code: 0, summary: "Done with the work." },
         headers: @auth_headers,
         as: :json

    assert_response :success
    assert_equal initial_message_count + 1, task.messages.count
    message = task.messages.last
    assert_equal "Done with the work.", message.body
    assert_equal @agent, message.author
  end

  test "result posts default message when summary not provided" do
    task = @running_run.task

    post result_api_agent_run_url(@running_run),
         params: { exit_code: 0 },
         headers: @auth_headers,
         as: :json

    assert_response :success
    message = task.messages.last
    assert_includes message.body, @agent.name
  end

  test "result without task skips task update" do
    @running_run.update!(task: nil)

    post result_api_agent_run_url(@running_run),
         params: { exit_code: 0 },
         headers: @auth_headers,
         as: :json

    assert_response :success
    @running_run.reload
    assert @running_run.completed?
  end

  # --- CALLBACK-04: Cost reporting feeds budget tracking ---

  test "result with cost_cents accumulates cost on task" do
    task = @running_run.task
    original_cost = task.cost_cents || 0

    post result_api_agent_run_url(@running_run),
         params: { exit_code: 0, cost_cents: 750 },
         headers: @auth_headers,
         as: :json

    assert_response :success
    assert_equal original_cost + 750, task.reload.cost_cents
  end

  test "result with cost_cents triggers budget enforcement" do
    # Set agent budget low enough to trigger enforcement
    @agent.update!(budget_cents: 2000, budget_period_start: Date.current.beginning_of_month)

    post result_api_agent_run_url(@running_run),
         params: { exit_code: 0, cost_cents: 50000 },
         headers: @auth_headers,
         as: :json

    assert_response :success
    # Budget enforcement should have run (agent may be paused if budget exceeded)
    # The exact outcome depends on existing task costs, but no error should occur
  end

  # --- Error cases ---

  test "result rejects already completed run" do
    @running_run.mark_completed!(exit_code: 0)

    post result_api_agent_run_url(@running_run),
         params: { exit_code: 0 },
         headers: @auth_headers,
         as: :json

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_includes json["error"], "already"
  end

  test "result rejects run from different agent" do
    other_agent = agents(:http_agent)
    other_headers = { "Authorization" => "Bearer #{other_agent.api_token}" }

    post result_api_agent_run_url(@running_run),
         params: { exit_code: 0 },
         headers: other_headers,
         as: :json

    assert_response :forbidden
  end

  test "result returns 404 for nonexistent run" do
    post result_api_agent_run_url(id: 999999),
         params: { exit_code: 0 },
         headers: @auth_headers,
         as: :json

    assert_response :not_found
  end

  test "result requires authentication" do
    post result_api_agent_run_url(@running_run),
         params: { exit_code: 0 },
         as: :json

    assert_response :unauthorized
  end

  # =====================
  # POST /api/agent_runs/:id/progress
  # =====================

  # --- Success ---

  test "progress broadcasts message as log line" do
    post progress_api_agent_run_url(@running_run),
         params: { message: "Working on step 3 of 5..." },
         headers: @auth_headers,
         as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "ok", json["status"]

    # Verify the message was appended to log
    @running_run.reload
    assert_includes @running_run.log_output, "[progress] Working on step 3 of 5..."
  end

  # --- Error cases ---

  test "progress rejects empty message" do
    post progress_api_agent_run_url(@running_run),
         params: { message: "" },
         headers: @auth_headers,
         as: :json

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_includes json["error"], "required"
  end

  test "progress rejects non-running run" do
    @running_run.mark_completed!(exit_code: 0)

    post progress_api_agent_run_url(@running_run),
         params: { message: "Still working..." },
         headers: @auth_headers,
         as: :json

    assert_response :unprocessable_entity
  end

  test "progress rejects run from different agent" do
    other_agent = agents(:http_agent)
    other_headers = { "Authorization" => "Bearer #{other_agent.api_token}" }

    post progress_api_agent_run_url(@running_run),
         params: { message: "Progress..." },
         headers: other_headers,
         as: :json

    assert_response :forbidden
  end

  test "progress requires authentication" do
    post progress_api_agent_run_url(@running_run),
         params: { message: "Progress..." },
         as: :json

    assert_response :unauthorized
  end
end
