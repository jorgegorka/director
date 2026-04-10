require "test_helper"

class Dashboard::OverviewTest < ActiveSupport::TestCase
  setup do
    @project = projects(:acme)
    @overview = Dashboard::Overview.new(@project)
  end

  test "tasks_active_count returns non-completed non-cancelled tasks" do
    expected = @project.tasks.active.count
    assert_equal expected, @overview.tasks_active_count
    assert @overview.tasks_active_count > 0
  end

  test "tasks_completed_count returns completed tasks" do
    expected = @project.tasks.completed.count
    assert_equal expected, @overview.tasks_completed_count
    assert @overview.tasks_completed_count > 0
  end

  test "total_roles_count returns non-terminated roles" do
    expected = @project.roles.active.count
    assert_equal expected, @overview.total_roles_count
  end

  test "roles_online_count returns idle and running roles" do
    expected = @project.roles.active.online.count
    assert_equal expected, @overview.roles_online_count
  end

  test "running_roles returns only roles with running status" do
    assert_empty @overview.running_roles

    roles(:developer).update_column(:status, Role.statuses[:running])
    overview = Dashboard::Overview.new(@project)
    assert_includes overview.running_roles, roles(:developer)
  end

  test "running_roles eager loads role_runs and tasks" do
    roles(:developer).update_column(:status, Role.statuses[:running])
    overview = Dashboard::Overview.new(@project)
    role = overview.running_roles.first
    assert role.association(:role_runs).loaded?
  end

  test "budget_roles returns roles with budget ordered by title" do
    roles = @overview.budget_roles
    assert roles.all? { |r| r.budget_cents.present? }
    assert_equal roles.map(&:title).sort, roles.map(&:title)
  end

  test "budget_roles preloads monthly spend" do
    @overview.budget_roles
    assert_kind_of Numeric, @overview.total_spend_cents
  end

  test "total_budget_cents sums budget_cents across budget roles" do
    expected = @project.roles.active.with_budget.sum(:budget_cents)
    assert_equal expected, @overview.total_budget_cents
  end

  test "show_budget? returns true when roles have budgets" do
    assert @overview.show_budget?
  end

  test "show_budget? returns false when no roles have budgets" do
    overview = Dashboard::Overview.new(projects(:widgets))
    assert_not overview.show_budget?
  end

  test "top_root_task returns a root task from the project" do
    top = @overview.top_root_task
    assert_not_nil top
    assert_nil top.parent_task_id
    assert_equal @overview.project.id, top.project_id
  end

  test "scoped to project only" do
    widgets_overview = Dashboard::Overview.new(projects(:widgets))
    assert_not_equal @overview.total_roles_count, widgets_overview.total_roles_count
  end
end
