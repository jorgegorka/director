require "test_helper"

class BudgetEnforcementServiceTest < ActiveSupport::TestCase
  setup do
    @agent = agents(:claude_agent)
    @company = companies(:acme)
    # Clear any existing notifications for clean tests
    Notification.where(notifiable: @agent).delete_all
  end

  test "pauses agent when budget is exhausted" do
    @agent.update_columns(budget_cents: 1, status: Agent.statuses[:idle])
    # Agent has tasks with cost > $0.01 from fixtures (design_homepage + completed_task = 3700 cents)
    BudgetEnforcementService.check!(@agent)
    @agent.reload
    assert @agent.paused?
    assert_match /Budget exhausted/, @agent.pause_reason
    assert @agent.paused_at.present?
  end

  test "creates budget_exhausted notification when agent paused" do
    @agent.update_columns(budget_cents: 1, status: Agent.statuses[:idle])
    assert_difference -> { Notification.where(action: "budget_exhausted").count } do
      BudgetEnforcementService.check!(@agent)
    end
    notification = Notification.where(notifiable: @agent, action: "budget_exhausted").last
    assert_equal "budget_exhausted", notification.action
    assert_equal @agent.name, notification.metadata["agent_name"]
  end

  test "creates budget_alert notification at 80% threshold" do
    # Create a task with known cost in current period to guarantee spend
    Task.create!(title: "Cost task", company: @company, assignee: @agent, cost_cents: 8500)
    @agent.reload
    # Fixture tasks for claude_agent: design_homepage (1500) + completed_task (2200) = 3700
    # Plus new task 8500 = 12200 total spend.
    # Set budget_cents: 15000 → utilization = 12200/15000 = 81.3% (above 80% threshold, not exhausted)
    @agent.update_columns(budget_cents: 15000, budget_period_start: Date.current.beginning_of_month)
    assert_difference -> { Notification.where(action: "budget_alert").count } do
      BudgetEnforcementService.check!(@agent)
    end
  end

  test "does not create duplicate alert in same budget period" do
    Task.create!(title: "Cost task", company: @company, assignee: @agent, cost_cents: 8500)
    @agent.reload
    # Same budget setup as alert test: 12200 spend / 15000 budget = 81.3% (alert, not exhausted)
    @agent.update_columns(budget_cents: 15000, budget_period_start: Date.current.beginning_of_month)
    BudgetEnforcementService.check!(@agent)
    assert_no_difference -> { Notification.where(action: "budget_alert").count } do
      BudgetEnforcementService.check!(@agent)
    end
  end

  test "does not create duplicate exhausted notification in same period" do
    @agent.update_columns(budget_cents: 1, status: Agent.statuses[:idle])
    BudgetEnforcementService.check!(@agent)
    @agent.reload
    # Reset status to idle to allow re-check (simulating manual unpause)
    @agent.update_columns(status: Agent.statuses[:idle])
    assert_no_difference -> { Notification.where(notifiable: @agent, action: "budget_exhausted").count } do
      BudgetEnforcementService.check!(@agent)
    end
  end

  test "does nothing when agent has no budget configured" do
    @agent.update_columns(budget_cents: nil)
    assert_no_difference -> { Notification.count } do
      BudgetEnforcementService.check!(@agent)
    end
  end

  test "does nothing for terminated agent" do
    @agent.update_columns(status: Agent.statuses[:terminated], budget_cents: 1)
    assert_no_difference -> { Notification.count } do
      BudgetEnforcementService.check!(@agent)
    end
  end

  test "does not re-pause already budget-paused agent" do
    @agent.update_columns(
      budget_cents: 1,
      status: Agent.statuses[:paused],
      pause_reason: "Budget exhausted: already paused",
      paused_at: 1.hour.ago
    )
    original_paused_at = @agent.paused_at
    BudgetEnforcementService.check!(@agent)
    @agent.reload
    assert_equal original_paused_at.to_i, @agent.paused_at.to_i
  end

  test "notifies all company owners and admins" do
    @agent.update_columns(budget_cents: 1, status: Agent.statuses[:idle])
    owner_admin_count = @company.memberships.where(role: [ :owner, :admin ]).count
    assert_difference -> { Notification.where(action: "budget_exhausted").count }, owner_admin_count do
      BudgetEnforcementService.check!(@agent)
    end
  end

  test "does not alert when well under budget" do
    @agent.update_columns(budget_cents: 999_999_99)
    assert_no_difference -> { Notification.count } do
      BudgetEnforcementService.check!(@agent)
    end
  end

  test "notification metadata includes budget details" do
    @agent.update_columns(budget_cents: 1, status: Agent.statuses[:idle])
    BudgetEnforcementService.check!(@agent)
    notification = Notification.where(notifiable: @agent, action: "budget_exhausted").last
    assert notification.metadata["budget_cents"].present?
    assert notification.metadata["spent_cents"].present?
    assert notification.metadata["period_start"].present?
    assert_equal @agent.id, notification.metadata["agent_id"]
  end
end
