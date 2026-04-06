require "test_helper"

class GoalTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @project = projects(:acme)
    @other_project = projects(:widgets)
    @mission = goals(:acme_mission)
    @objective_one = goals(:acme_objective_one)
    @objective_two = goals(:acme_objective_two)
    @sub_objective = goals(:acme_sub_objective)
    @widgets_mission = goals(:widgets_mission)
  end

  # --- Validations ---

  test "valid with title and project" do
    goal = Goal.new(title: "New Goal", project: @project)
    assert goal.valid?
  end

  test "invalid without title" do
    goal = Goal.new(title: nil, project: @project)
    assert_not goal.valid?
    assert_includes goal.errors[:title], "can't be blank"
  end

  test "title unique within project" do
    duplicate = Goal.new(title: "Launch MVP by Q2", project: @project)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:title], "has already been taken"
  end

  test "allows same title across projects" do
    goal = Goal.new(title: "Launch MVP by Q2", project: @other_project)
    assert goal.valid?
  end

  # --- Associations ---

  test "belongs to project" do
    assert_equal @project, @mission.project
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
    Current.project = @project
    ordered = @project.goals.ordered.to_a
    assert_equal @mission, ordered.first
  ensure
    Current.project = nil
  end

  test "for_current_project scopes to tenant" do
    Current.project = @project
    goals = Goal.for_current_project
    assert_includes goals, @mission
    assert_not_includes goals, @widgets_mission
  ensure
    Current.project = nil
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
      Task.create!(title: "New task", project: @project, creator: roles(:ceo), goal: @objective_two)
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

  test "task invalid when goal from different project" do
    task = Task.new(title: "Bad Goal Task", project: @project, goal: @widgets_mission)
    assert_not task.valid?
    assert_includes task.errors[:goal], "must belong to the same project"
  end

  # --- finalized? ---

  test "finalized? returns true when completion is 100" do
    @mission.update_column(:completion_percentage, 100)
    assert @mission.finalized?
  end

  test "finalized? returns false when completion is below 100" do
    @mission.update_column(:completion_percentage, 99)
    assert_not @mission.finalized?
  end

  # --- Goal assignment wake guard ---

  test "assigning a finalized goal does not trigger wake" do
    role = roles(:cto)
    @objective_two.update_column(:completion_percentage, 100)

    assert_no_enqueued_jobs(only: ExecuteRoleJob) do
      @objective_two.update!(role: role)
    end
  end

  test "assigning an incomplete goal triggers wake" do
    RoleRun.active.delete_all
    role = roles(:cto)
    @objective_two.update_column(:completion_percentage, 50)

    assert_enqueued_with(job: ExecuteRoleJob) do
      @objective_two.update!(role: role)
    end
  end
end
