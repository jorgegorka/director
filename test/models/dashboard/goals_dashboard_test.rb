require "test_helper"

class Dashboard::GoalsDashboardTest < ActiveSupport::TestCase
  setup do
    @project = projects(:acme)
    @dashboard = Dashboard::GoalsDashboard.new(@project)
  end

  test "goals returns root tasks ordered by priority" do
    goals = @dashboard.goals
    assert goals.any?
    assert goals.all? { |t| t.parent_task_id.nil? }
  end

  test "goals eager loads assignee and subtasks" do
    goal = @dashboard.goals.first
    assert goal.association(:assignee).loaded?
    assert goal.association(:subtasks).loaded?
  end

  test "goals are ordered by priority descending" do
    priorities = @dashboard.goals.map(&:priority)
    priority_values = priorities.map { |p| Task.priorities[p] }
    assert_equal priority_values, priority_values.sort.reverse
  end

  test "attention returns an AttentionItems instance" do
    assert_kind_of Dashboard::AttentionItems, @dashboard.attention
  end

  test "attention is scoped to the same project" do
    assert_equal @project, @dashboard.attention.project
  end

  test "name delegates to project" do
    assert_equal @project.name, @dashboard.name
  end

  test "scoped to project only" do
    widgets_dashboard = Dashboard::GoalsDashboard.new(projects(:widgets))
    assert_not_equal @dashboard.goals.count, widgets_dashboard.goals.count
  end
end
