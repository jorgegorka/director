require "test_helper"

class Goals::EvaluationTest < ActiveSupport::TestCase
  setup do
    ENV["ANTHROPIC_API_KEY"] = "test-key"

    @company = companies(:acme)
    @role = roles(:cto)
    @goal = goals(:acme_objective_one)

    # Create a completed task with goal
    @task = Task.create!(
      title: "Build search feature",
      description: "Add full-text search",
      company: @company,
      assignee: @role,
      goal: @goal,
      status: :open
    )
    @task.update_columns(status: 3, completed_at: Time.current)
    @task.reload

    # Add a work output message
    Message.create!(task: @task, author: @role, body: "I implemented full-text search using pg_search.")
  end

  # --- Pass flow ---

  test "creates a passing GoalEvaluation when AI returns pass" do
    stub_ai_response(result: "pass", feedback: "Search feature directly advances MVP launch.")

    assert_difference "GoalEvaluation.count", 1 do
      Goals::Evaluation.call(@task)
    end

    evaluation = GoalEvaluation.last
    assert evaluation.pass?
    assert_equal "Search feature directly advances MVP launch.", evaluation.feedback
    assert_equal 1, evaluation.attempt_number
    assert_equal @task.id, evaluation.task_id
    assert_equal @goal.id, evaluation.goal_id
    assert_equal @role.id, evaluation.role_id
    assert_equal @company.id, evaluation.company_id
  end

  test "task stays completed on pass" do
    stub_ai_response(result: "pass", feedback: "Good.")

    Goals::Evaluation.call(@task)
    @task.reload

    assert @task.completed?
  end

  test "does not wake role on pass" do
    stub_ai_response(result: "pass", feedback: "Good.")

    assert_no_difference "HeartbeatEvent.count" do
      Goals::Evaluation.call(@task)
    end
  end

  # --- Fail flow ---

  test "creates a failing GoalEvaluation when AI returns fail" do
    stub_ai_response(result: "fail", feedback: "This doesn't advance the goal.")

    assert_difference "GoalEvaluation.count", 1 do
      Goals::Evaluation.call(@task)
    end

    evaluation = GoalEvaluation.last
    assert evaluation.fail?
    assert_equal "This doesn't advance the goal.", evaluation.feedback
  end

  test "reopens task to in_progress on fail" do
    stub_ai_response(result: "fail", feedback: "Not aligned.")

    Goals::Evaluation.call(@task)
    @task.reload

    assert @task.in_progress?
    assert_nil @task.completed_at
  end

  test "posts feedback message on task on fail" do
    stub_ai_response(result: "fail", feedback: "Needs more alignment.")

    assert_difference "Message.count", 1 do
      Goals::Evaluation.call(@task)
    end

    message = @task.messages.order(:created_at).last
    assert_includes message.body, "Needs more alignment."
    assert_includes message.body, "Goal Evaluation"
  end

  test "wakes role with goal_evaluation_failed trigger on fail" do
    stub_ai_response(result: "fail", feedback: "Not aligned.")

    assert_difference "HeartbeatEvent.count", 1 do
      Goals::Evaluation.call(@task)
    end

    event = HeartbeatEvent.order(:created_at).last
    assert event.goal_evaluation_failed?
    assert_equal @role.id, event.role_id
  end

  # --- Retry exhaustion ---

  test "blocks task after MAX_ATTEMPTS failed evaluations" do
    GoalEvaluation.create!(company: @company, task: @task, goal: @goal, role: @role,
      result: :fail, feedback: "Attempt 1", attempt_number: 1, cost_cents: 50)
    GoalEvaluation.create!(company: @company, task: @task, goal: @goal, role: @role,
      result: :fail, feedback: "Attempt 2", attempt_number: 2, cost_cents: 50)

    stub_ai_response(result: "fail", feedback: "Still not aligned.")

    Goals::Evaluation.call(@task)
    @task.reload

    assert @task.blocked?
  end

  test "records audit event on retry exhaustion" do
    GoalEvaluation.create!(company: @company, task: @task, goal: @goal, role: @role,
      result: :fail, feedback: "Attempt 1", attempt_number: 1, cost_cents: 50)
    GoalEvaluation.create!(company: @company, task: @task, goal: @goal, role: @role,
      result: :fail, feedback: "Attempt 2", attempt_number: 2, cost_cents: 50)

    stub_ai_response(result: "fail", feedback: "Still not aligned.")

    assert_difference "AuditEvent.count" do
      Goals::Evaluation.call(@task)
    end

    audit = AuditEvent.where(action: "goal_evaluation_exhausted").last
    assert_equal @task, audit.auditable
  end

  test "skips evaluation when max attempts already reached" do
    3.times do |i|
      GoalEvaluation.create!(company: @company, task: @task, goal: @goal, role: @role,
        result: :fail, feedback: "Attempt #{i + 1}", attempt_number: i + 1, cost_cents: 50)
    end

    assert_no_difference "GoalEvaluation.count" do
      Goals::Evaluation.call(@task)
    end
  end

  # --- Edge cases ---

  test "skips when task has no goal" do
    @task.update_columns(goal_id: nil)
    @task.reload

    assert_no_difference "GoalEvaluation.count" do
      Goals::Evaluation.call(@task)
    end
  end

  test "skips when task is not completed" do
    @task.update_columns(status: 1)  # in_progress
    @task.reload

    assert_no_difference "GoalEvaluation.count" do
      Goals::Evaluation.call(@task)
    end
  end

  # --- Budget charging ---

  test "adds evaluation cost to task cost_cents" do
    stub_ai_response(result: "pass", feedback: "Good.", input_tokens: 500, output_tokens: 100)

    Goals::Evaluation.call(@task)
    @task.reload

    assert @task.cost_cents.present?
    assert @task.cost_cents > 0
  end

  private

  def stub_ai_response(result:, feedback:, input_tokens: 100, output_tokens: 50)
    response_text = { result: result, feedback: feedback }.to_json
    mock_response = {
      "content" => [ { "type" => "text", "text" => response_text } ],
      "usage" => { "input_tokens" => input_tokens, "output_tokens" => output_tokens }
    }.to_json

    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_return(status: 200, body: mock_response, headers: { "Content-Type" => "application/json" })
  end
end
