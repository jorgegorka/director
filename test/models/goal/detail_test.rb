require "test_helper"

class Goal::DetailTest < ActiveSupport::TestCase
  setup do
    @mission = goals(:acme_mission)
    @objective_one = goals(:acme_objective_one)
    @objective_two = goals(:acme_objective_two)
    @sub_objective = goals(:acme_sub_objective)
  end

  # --- children ---

  test "children returns ordered child goals" do
    detail = Goal::Detail.new(@mission)

    assert_equal [ @objective_one, @objective_two ], detail.children.to_a
  end

  test "children is empty for leaf goal" do
    detail = Goal::Detail.new(@sub_objective)

    assert_empty detail.children
  end

  test "children is memoized" do
    detail = Goal::Detail.new(@mission)

    assert_same detail.children, detail.children
  end

  # --- tasks ---

  test "tasks returns tasks for the goal" do
    detail = Goal::Detail.new(@objective_one)

    titles = detail.tasks.map(&:title)
    assert_includes titles, "Design homepage"
    assert_includes titles, "Fix login bug"
  end

  test "tasks is empty when goal has no tasks" do
    detail = Goal::Detail.new(@mission)

    assert_empty detail.tasks
  end

  test "tasks is memoized" do
    detail = Goal::Detail.new(@objective_one)

    assert_same detail.tasks, detail.tasks
  end

  # --- eval_total ---

  test "eval_total counts evaluations across goal and descendants" do
    detail = Goal::Detail.new(@objective_one)

    # passing_eval on acme_objective_one + failed_eval on acme_sub_objective
    assert_equal 2, detail.eval_total
  end

  test "eval_total is zero when no evaluations exist" do
    detail = Goal::Detail.new(@objective_two)

    assert_equal 0, detail.eval_total
  end

  # --- eval_pass_count ---

  test "eval_pass_count counts only passing evaluations" do
    detail = Goal::Detail.new(@objective_one)

    assert_equal 1, detail.eval_pass_count
  end

  test "eval_pass_count is zero when no evaluations exist" do
    detail = Goal::Detail.new(@objective_two)

    assert_equal 0, detail.eval_pass_count
  end

  # --- eval_pass_rate ---

  test "eval_pass_rate computes percentage" do
    detail = Goal::Detail.new(@objective_one)

    # 1 pass out of 2 total = 50%
    assert_equal 50, detail.eval_pass_rate
  end

  test "eval_pass_rate returns zero when no evaluations" do
    detail = Goal::Detail.new(@objective_two)

    assert_equal 0, detail.eval_pass_rate
  end

  # --- boolean helpers ---

  test "any_children? is true when children exist" do
    detail = Goal::Detail.new(@mission)

    assert detail.any_children?
  end

  test "any_children? is false for leaf goal" do
    detail = Goal::Detail.new(@sub_objective)

    assert_not detail.any_children?
  end

  test "any_tasks? is true when tasks exist" do
    detail = Goal::Detail.new(@objective_one)

    assert detail.any_tasks?
  end

  test "any_tasks? is false when no tasks" do
    detail = Goal::Detail.new(@mission)

    assert_not detail.any_tasks?
  end

  test "any_evaluations? is true when evaluations exist" do
    detail = Goal::Detail.new(@objective_one)

    assert detail.any_evaluations?
  end

  test "any_evaluations? is false when no evaluations" do
    detail = Goal::Detail.new(@objective_two)

    assert_not detail.any_evaluations?
  end

  # --- hierarchical aggregation ---

  test "evaluations aggregate across full descendant tree" do
    detail = Goal::Detail.new(@mission)

    # mission -> objective_one (passing_eval) -> sub_objective (failed_eval)
    # mission -> objective_two (no evals)
    assert_equal 2, detail.eval_total
    assert_equal 1, detail.eval_pass_count
    assert_equal 50, detail.eval_pass_rate
  end

  test "leaf goal only counts its own evaluations" do
    detail = Goal::Detail.new(@sub_objective)

    # failed_eval is on acme_sub_objective
    assert_equal 1, detail.eval_total
    assert_equal 0, detail.eval_pass_count
  end
end
