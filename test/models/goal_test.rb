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

  test "title unique within same parent and company" do
    duplicate = Goal.new(title: "Launch MVP by Q2", company: @company, parent: @mission)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:title], "already exists under this parent"
  end

  test "allows same title under different parents" do
    goal = Goal.new(title: "Launch MVP by Q2", company: @company, parent: @objective_two)
    assert goal.valid?
  end

  test "invalid when parent belongs to different company" do
    goal = Goal.new(title: "Cross-company", company: @other_company, parent: @mission)
    assert_not goal.valid?
    assert_includes goal.errors[:parent], "must belong to the same company"
  end

  test "invalid when parent is self" do
    @mission.parent = @mission
    assert_not @mission.valid?
    assert_includes @mission.errors[:parent], "cannot be the goal itself"
  end

  test "invalid when parent is a descendant" do
    # mission -> objective_one -> sub_objective. Setting mission's parent to sub_objective creates a cycle.
    @mission.parent = @sub_objective
    assert_not @mission.valid?
    assert_includes @mission.errors[:parent], "cannot be a descendant of this goal"
  end

  # --- Associations ---

  test "belongs to company" do
    assert_equal @company, @mission.company
  end

  test "belongs to parent optionally" do
    assert_equal @mission, @objective_one.parent
    assert_nil @mission.parent
  end

  test "has many children" do
    assert_includes @mission.children, @objective_one
    assert_includes @mission.children, @objective_two
    assert_not_includes @mission.children, @sub_objective
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

  test "destroying goal destroys child goals" do
    assert Goal.exists?(goals(:acme_sub_objective).id)
    @objective_one.destroy
    assert_not Goal.exists?(goals(:acme_sub_objective).id)
  end

  # --- Scopes ---

  test "roots returns only top-level goals" do
    Current.company = @company
    roots = Goal.for_current_company.roots
    assert_includes roots, @mission
    assert_not_includes roots, @objective_one
    assert_not_includes roots, @objective_two
    assert_not_includes roots, @sub_objective
  ensure
    Current.company = nil
  end

  test "ordered scope sorts by position then title" do
    Current.company = @company
    ordered = @mission.children.ordered.to_a
    # objective_one has position 0, objective_two has position 1
    assert_equal @objective_one, ordered.first
    assert_equal @objective_two, ordered.last
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

  # --- Tree traversal ---

  test "ancestors returns parent chain" do
    ancestors = @sub_objective.ancestors
    assert_equal [ @objective_one, @mission ], ancestors
  end

  test "ancestors of root is empty" do
    assert_empty @mission.ancestors
  end

  test "descendants returns all children recursively" do
    descendants = @mission.descendants
    assert_includes descendants, @objective_one
    assert_includes descendants, @objective_two
    assert_includes descendants, @sub_objective
    assert_equal 3, descendants.size
  end

  test "root? returns true for mission" do
    assert @mission.root?
  end

  test "root? returns false for objective" do
    assert_not @objective_one.root?
  end

  test "depth returns nesting level" do
    assert_equal 0, @mission.depth
    assert_equal 1, @objective_one.depth
    assert_equal 2, @sub_objective.depth
  end

  test "mission? is alias for root?" do
    assert @mission.mission?
    assert_not @objective_one.mission?
  end

  test "ancestry_chain returns breadcrumb path" do
    chain = @sub_objective.ancestry_chain
    assert_equal [ @mission, @objective_one, @sub_objective ], chain
  end

  # --- Completion percentage recalculation ---

  test "recalculate_completion! with no tasks returns 0" do
    @objective_two.recalculate_completion!
    assert_equal 0, @objective_two.reload.completion_percentage
  end

  test "recalculate_completion! computes from task statuses" do
    @sub_objective.recalculate_completion!
    # acme_sub_objective: 1 completed + 1 open = 50%
    assert_equal 50, @sub_objective.reload.completion_percentage
  end

  test "recalculate_completion! rolls up through children" do
    @objective_one.recalculate_completion!
    # acme_objective_one subtree: 5 tasks, 2 completed = 40%
    assert_equal 40, @objective_one.reload.completion_percentage
  end

  test "creating a task enqueues recalculation job" do
    assert_enqueued_with(job: RecalculateGoalCompletionJob, args: [@objective_two.id]) do
      Task.create!(title: "New task", company: @company, creator: roles(:ceo), goal: @objective_two)
    end
  end

  test "updating a task enqueues recalculation job" do
    task = tasks(:write_tests)  # under acme_sub_objective
    assert_enqueued_with(job: RecalculateGoalCompletionJob, args: [@sub_objective.id]) do
      task.update!(status: :completed)
    end
  end

  test "recalculation job updates goal and ancestor completion" do
    RecalculateGoalCompletionJob.perform_now(@sub_objective.id)
    # acme_sub_objective: 1 completed + 1 open = 50%
    assert_equal 50, @sub_objective.reload.completion_percentage
    # objective_one subtree: 5 tasks, 2 completed = 40%
    assert_equal 40, @objective_one.reload.completion_percentage
    # mission: same subtree = 40%
    assert_equal 40, @mission.reload.completion_percentage
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
