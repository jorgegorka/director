require "test_helper"

class Dashboard::OverviewTest < ActiveSupport::TestCase
  setup do
    @company = companies(:acme)
    @overview = Dashboard::Overview.new(@company)
  end

  test "tasks_active_count returns non-completed non-cancelled tasks" do
    expected = @company.tasks.active.count
    assert_equal expected, @overview.tasks_active_count
    assert @overview.tasks_active_count > 0
  end

  test "tasks_completed_count returns completed tasks" do
    expected = @company.tasks.completed.count
    assert_equal expected, @overview.tasks_completed_count
    assert @overview.tasks_completed_count > 0
  end

  test "total_roles_count returns non-terminated roles" do
    expected = @company.roles.active.count
    assert_equal expected, @overview.total_roles_count
  end

  test "roles_online_count returns idle and running roles" do
    expected = @company.roles.active.online.count
    assert_equal expected, @overview.roles_online_count
  end

  test "running_roles returns only roles with running status" do
    assert_empty @overview.running_roles

    roles(:developer).update_column(:status, Role.statuses[:running])
    overview = Dashboard::Overview.new(@company)
    assert_includes overview.running_roles, roles(:developer)
  end

  test "running_roles eager loads role_runs and tasks" do
    roles(:developer).update_column(:status, Role.statuses[:running])
    overview = Dashboard::Overview.new(@company)
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
    expected = @company.roles.active.with_budget.sum(:budget_cents)
    assert_equal expected, @overview.total_budget_cents
  end

  test "show_budget? returns true when roles have budgets" do
    assert @overview.show_budget?
  end

  test "show_budget? returns false when no roles have budgets" do
    overview = Dashboard::Overview.new(companies(:widgets))
    assert_not overview.show_budget?
  end

  test "mission returns first root goal" do
    assert_equal goals(:acme_mission), @overview.mission
  end

  test "show_mission? returns true when mission exists" do
    assert @overview.show_mission?
  end

  test "show_mission? returns false when no goals exist" do
    overview = Dashboard::Overview.new(companies(:widgets).tap { |c| c.goals.destroy_all })
    assert_not overview.show_mission?
  end

  test "scoped to company only" do
    widgets_overview = Dashboard::Overview.new(companies(:widgets))
    assert_not_equal @overview.total_roles_count, widgets_overview.total_roles_count
  end
end
