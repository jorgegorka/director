require "test_helper"

class GoalTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @company = companies(:acme)
    @other_company = companies(:widgets)
    @mission = goals(:acme_mission)
    @objective_one = goals(:acme_objective_one)
    @objective_two = goals(:acme_objective_two)
    @sub_objective = goals(:acme_sub_objective)
    @widgets_mission = goals(:widgets_mission)
  end

  # --- Validations ---

  test "valid with title and company" do
    goal = Goal.new(title: "New Goal", company: @company)
    assert goal.valid?
  end

  test "invalid without title" do
    goal = Goal.new(title: nil, company: @company)
    assert_not goal.valid?
    assert_includes goal.errors[:title], "can't be blank"
  end

  test "title unique within company" do
    duplicate = Goal.new(title: "Launch MVP by Q2", company: @company)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:title], "has already been taken"
  end

  test "allows same title across companies" do
    goal = Goal.new(title: "Launch MVP by Q2", company: @other_company)
    assert goal.valid?
  end

  # --- Associations ---

  test "belongs to company" do
    assert_equal @company, @mission.company
  end

  test "has many tasks" do
    assert_includes @objective_one.tasks, tasks(:design_homepage)
    assert_includes @objective_one.tasks, tasks(:fix_login_bug)
  end

  test "destroying goal nullifies task goal_id" do
    task = tasks(:completed_task)
    assert_equal @sub_objective.id, task.goal_id

    @sub_objective.destroy
    task.reload
    assert_nil task.goal_id
  end

  # --- Scopes ---

  test "ordered scope sorts by position then title" do
    Current.company = @company
    ordered = @company.goals.ordered.to_a
    assert_equal @mission, ordered.first
  ensure
    Current.company = nil
  end

  test "for_current_company scopes to tenant" do
    Current.company = @company
    goals = Goal.for_current_company
    assert_includes goals, @mission
    assert_not_includes goals, @widgets_mission
  ensure
    Current.company = nil
  end

  # --- Completion percentage recalculation ---

  test "recalculate_completion! with no tasks returns 0" do
    @objective_two.recalculate_completion!
    assert_equal 0, @objective_two.reload.completion_percentage
  end

  test "recalculate_completion! computes from task statuses" do
    @sub_objective.recalculate_completion!
    # acme_sub_objective: 1 completed (completed_task) + 1 open (write_tests) = 50%
    assert_equal 50, @sub_objective.reload.completion_percentage
  end

  test "recalculate_completion! only counts direct tasks" do
    @objective_one.recalculate_completion!
    # acme_objective_one direct tasks: design_homepage (in_progress), fix_login_bug (open), eval_ready_task (completed) = 33%
    assert_equal 33, @objective_one.reload.completion_percentage
  end

  test "creating a task enqueues recalculation job" do
    assert_enqueued_with(job: RecalculateGoalCompletionJob, args: [ @objective_two.id ]) do
      Task.create!(title: "New task", company: @company, creator: roles(:ceo), goal: @objective_two)
    end
  end

  test "updating a task enqueues recalculation job" do
    task = tasks(:write_tests)
    assert_enqueued_with(job: RecalculateGoalCompletionJob, args: [ @sub_objective.id ]) do
      task.update!(status: :completed)
    end
  end

  test "recalculation job updates only the target goal" do
    RecalculateGoalCompletionJob.perform_now(@sub_objective.id)
    assert_equal 50, @sub_objective.reload.completion_percentage
  end

  # --- Task-Goal association ---

  test "task valid without goal" do
    task = tasks(:subtask_one)
    assert_nil task.goal
    assert task.valid?
  end

  test "task valid with goal" do
    task = tasks(:design_homepage)
    assert_equal @objective_one, task.goal
    assert task.valid?
  end

  test "task invalid when goal from different company" do
    task = Task.new(title: "Bad Goal Task", company: @company, goal: @widgets_mission)
    assert_not task.valid?
    assert_includes task.errors[:goal], "must belong to the same company"
  end
end
