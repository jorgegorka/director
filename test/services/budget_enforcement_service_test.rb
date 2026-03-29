require "test_helper"

class BudgetEnforcementServiceTest < ActiveSupport::TestCase
  setup do
    @role = roles(:cto)
    @company = companies(:acme)
    # Clear any existing notifications for clean tests
    Notification.where(notifiable: @role).delete_all
  end

  test "pauses role when budget is exhausted" do
    @role.update_columns(budget_cents: 1, status: Role.statuses[:idle])
    BudgetEnforcementService.check!(@role)
    @role.reload
    assert @role.paused?
    assert_match /Budget exhausted/, @role.pause_reason
    assert @role.paused_at.present?
  end

  test "creates budget_exhausted notification when role paused" do
    @role.update_columns(budget_cents: 1, status: Role.statuses[:idle])
    assert_difference -> { Notification.where(action: "budget_exhausted").count } do
      BudgetEnforcementService.check!(@role)
    end
    notification = Notification.where(notifiable: @role, action: "budget_exhausted").last
    assert_equal "budget_exhausted", notification.action
    assert_equal @role.title, notification.metadata["role_title"]
  end

  test "creates budget_alert notification at 80% threshold" do
    Task.create!(title: "Cost task", company: @company, assignee: @role, cost_cents: 8500)
    @role.reload
    @role.update_columns(budget_cents: 15000, budget_period_start: Date.current.beginning_of_month)
    assert_difference -> { Notification.where(action: "budget_alert").count } do
      BudgetEnforcementService.check!(@role)
    end
  end

  test "does not create duplicate alert in same budget period" do
    Task.create!(title: "Cost task", company: @company, assignee: @role, cost_cents: 8500)
    @role.reload
    @role.update_columns(budget_cents: 15000, budget_period_start: Date.current.beginning_of_month)
    BudgetEnforcementService.check!(@role)
    assert_no_difference -> { Notification.where(action: "budget_alert").count } do
      BudgetEnforcementService.check!(@role)
    end
  end

  test "does not create duplicate exhausted notification in same period" do
    @role.update_columns(budget_cents: 1, status: Role.statuses[:idle])
    BudgetEnforcementService.check!(@role)
    @role.reload
    @role.update_columns(status: Role.statuses[:idle])
    assert_no_difference -> { Notification.where(notifiable: @role, action: "budget_exhausted").count } do
      BudgetEnforcementService.check!(@role)
    end
  end

  test "does nothing when role has no budget configured" do
    @role.update_columns(budget_cents: nil)
    assert_no_difference -> { Notification.count } do
      BudgetEnforcementService.check!(@role)
    end
  end

  test "does nothing for terminated role" do
    @role.update_columns(status: Role.statuses[:terminated], budget_cents: 1)
    assert_no_difference -> { Notification.count } do
      BudgetEnforcementService.check!(@role)
    end
  end

  test "does not re-pause already budget-paused role" do
    @role.update_columns(
      budget_cents: 1,
      status: Role.statuses[:paused],
      pause_reason: "Budget exhausted: already paused",
      paused_at: 1.hour.ago
    )
    original_paused_at = @role.paused_at
    BudgetEnforcementService.check!(@role)
    @role.reload
    assert_equal original_paused_at.to_i, @role.paused_at.to_i
  end

  test "notifies all company owners and admins" do
    @role.update_columns(budget_cents: 1, status: Role.statuses[:idle])
    owner_admin_count = @company.memberships.where(role: [ :owner, :admin ]).count
    assert_difference -> { Notification.where(action: "budget_exhausted").count }, owner_admin_count do
      BudgetEnforcementService.check!(@role)
    end
  end

  test "does not alert when well under budget" do
    @role.update_columns(budget_cents: 999_999_99)
    assert_no_difference -> { Notification.count } do
      BudgetEnforcementService.check!(@role)
    end
  end

  test "notification metadata includes budget details" do
    @role.update_columns(budget_cents: 1, status: Role.statuses[:idle])
    BudgetEnforcementService.check!(@role)
    notification = Notification.where(notifiable: @role, action: "budget_exhausted").last
    assert notification.metadata["budget_cents"].present?
    assert notification.metadata["spent_cents"].present?
    assert notification.metadata["period_start"].present?
    assert_equal @role.id, notification.metadata["role_id"]
  end
end
