require "test_helper"

class GoalEvaluationTest < ActiveSupport::TestCase
  setup do
    @company = companies(:acme)
    @role = roles(:cto)
    @goal = goals(:acme_objective_one)
    @task = tasks(:eval_ready_task)
    @evaluation = goal_evaluations(:passing_eval)
  end

  # --- Associations ---

  test "belongs to company" do
    assert_equal @company, @evaluation.company
  end

  test "belongs to task" do
    assert_equal @task, @evaluation.task
  end

  test "belongs to goal" do
    assert_equal @goal, @evaluation.goal
  end

  test "belongs to role" do
    assert_equal @role, @evaluation.role
  end

  # --- Validations ---

  test "requires result" do
    evaluation = GoalEvaluation.new(
      company: @company, task: @task, goal: @goal, role: @role,
      feedback: "Good work", attempt_number: 1
    )
    assert_not evaluation.valid?
    assert_includes evaluation.errors[:result], "can't be blank"
  end

  test "requires feedback" do
    evaluation = GoalEvaluation.new(
      company: @company, task: @task, goal: @goal, role: @role,
      result: :pass, attempt_number: 1
    )
    assert_not evaluation.valid?
    assert_includes evaluation.errors[:feedback], "can't be blank"
  end

  test "requires attempt_number" do
    evaluation = GoalEvaluation.new(
      company: @company, task: @task, goal: @goal, role: @role,
      result: :pass, feedback: "Good"
    )
    assert_not evaluation.valid?
    assert_includes evaluation.errors[:attempt_number], "can't be blank"
  end

  test "attempt_number must be positive integer" do
    evaluation = GoalEvaluation.new(
      company: @company, task: @task, goal: @goal, role: @role,
      result: :pass, feedback: "Good", attempt_number: 0
    )
    assert_not evaluation.valid?
  end

  test "attempt_number must be unique per task" do
    duplicate = GoalEvaluation.new(
      company: @company, task: @task, goal: @goal, role: @role,
      result: :fail, feedback: "Not aligned", attempt_number: 1
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:attempt_number], "has already been taken"
  end

  test "cost_cents must be non-negative if present" do
    @evaluation.cost_cents = -1
    assert_not @evaluation.valid?
  end

  test "cost_cents can be nil" do
    @evaluation.cost_cents = nil
    assert @evaluation.valid?
  end

  # --- Enums ---

  test "result enum has pass and fail" do
    assert GoalEvaluation.new(result: :pass).pass?
    assert GoalEvaluation.new(result: :fail).fail?
  end

  # --- Scopes ---

  test "passed scope returns only passing evaluations" do
    results = GoalEvaluation.passed
    assert results.all?(&:pass?)
  end

  test "failed scope returns only failing evaluations" do
    results = GoalEvaluation.failed
    assert results.all?(&:fail?)
  end

  # --- MAX_ATTEMPTS constant ---

  test "MAX_ATTEMPTS is 3" do
    assert_equal 3, GoalEvaluation::MAX_ATTEMPTS
  end

  # --- Destruction ---

  test "goal evaluation is destroyed when task is destroyed" do
    assert_difference "GoalEvaluation.count", -1 do
      @task.destroy
    end
  end
end
