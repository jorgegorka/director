require "test_helper"

class GoalTest < ActiveSupport::TestCase
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

  # --- Progress calculation ---
  # Fixture setup:
  #   acme_objective_one: design_homepage (in_progress) + fix_login_bug (open) = 0 completed / 2 total
  #   acme_sub_objective: completed_task (completed) + write_tests (open) = 1 completed / 2 total
  #   acme_objective_two: no tasks
  #   acme_objective_one subtree: 4 tasks total, 1 completed = 0.25
  #   acme_mission subtree: 4 tasks total, 1 completed = 0.25

  test "progress of leaf goal with no tasks returns 0.0" do
    assert_equal 0.0, @objective_two.progress
  end

  test "progress of leaf goal with mixed tasks" do
    # acme_sub_objective: 1 completed + 1 open = 0.5
    assert_equal 0.5, @sub_objective.progress
  end

  test "progress rolls up through children" do
    # acme_objective_one: 2 direct tasks (0 completed) + sub_objective 2 tasks (1 completed) = 1/4 = 0.25
    assert_equal 0.25, @objective_one.progress
  end

  test "progress of mission rolls up entire tree" do
    # acme_mission subtree: 4 goal-linked tasks, 1 completed = 0.25
    assert_equal 0.25, @mission.progress
  end

  test "progress_percentage returns integer 0-100" do
    assert_equal 50, @sub_objective.progress_percentage
  end

  test "progress_percentage rounds correctly" do
    assert_equal 25, @objective_one.progress_percentage
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
