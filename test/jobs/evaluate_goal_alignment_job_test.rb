require "test_helper"

class EvaluateGoalAlignmentJobTest < ActiveSupport::TestCase
  setup do
    @company = companies(:acme)
    @role = roles(:cto)
    @goal = goals(:acme_objective_one)
    ENV["ANTHROPIC_API_KEY"] = "test-key"
  end

  test "skips when task not found" do
    assert_nothing_raised do
      EvaluateGoalAlignmentJob.perform_now(999999)
    end
  end

  test "skips when task is not completed" do
    task = tasks(:design_homepage)  # in_progress

    assert_no_difference "GoalEvaluation.count" do
      EvaluateGoalAlignmentJob.perform_now(task.id)
    end
  end

  test "skips when task has no goal" do
    task = Task.create!(
      title: "No goal task",
      company: @company,
      assignee: @role,
      status: :open
    )
    task.update_columns(status: 3, completed_at: Time.current)

    assert_no_difference "GoalEvaluation.count" do
      EvaluateGoalAlignmentJob.perform_now(task.id)
    end
  end

  test "calls Goals::Evaluation for eligible task" do
    task = Task.create!(
      title: "Eval job test",
      company: @company,
      assignee: @role,
      goal: @goal,
      status: :open
    )
    task.update_columns(status: 3, completed_at: Time.current)
    task.reload

    stub_ai_pass_response

    assert_difference "GoalEvaluation.count", 1 do
      EvaluateGoalAlignmentJob.perform_now(task.id)
    end
  end

  test "job is enqueued to default queue" do
    assert_equal "default", EvaluateGoalAlignmentJob.new.queue_name
  end

  private

  def stub_ai_pass_response
    response_text = { result: "pass", feedback: "Good work." }.to_json
    mock_response = {
      "content" => [ { "type" => "text", "text" => response_text } ],
      "usage" => { "input_tokens" => 100, "output_tokens" => 50 }
    }.to_json

    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_return(status: 200, body: mock_response, headers: { "Content-Type" => "application/json" })
  end
end
