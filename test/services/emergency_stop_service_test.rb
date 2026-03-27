require "test_helper"

class EmergencyStopServiceTest < ActiveSupport::TestCase
  setup do
    @company = companies(:acme)
    @user = users(:one)
    # Reset agent statuses for clean tests
    @company.agents.update_all(status: Agent.statuses[:idle], pause_reason: nil, paused_at: nil)
  end

  test "pauses all active agents in the company" do
    paused_count = EmergencyStopService.call!(company: @company, user: @user)
    assert paused_count > 0
    @company.agents.reload.each do |agent|
      assert agent.paused?, "Expected #{agent.name} to be paused"
      assert_equal EmergencyStopService::PAUSE_REASON, agent.pause_reason
    end
  end

  test "returns count of agents paused" do
    active_count = @company.agents.active.where.not(status: [ :paused, :terminated ]).count
    paused_count = EmergencyStopService.call!(company: @company, user: @user)
    assert_equal active_count, paused_count
  end

  test "does not pause already-paused agents" do
    @company.agents.first.update_columns(status: Agent.statuses[:paused], pause_reason: "Manual pause")
    paused_count = EmergencyStopService.call!(company: @company, user: @user)
    assert_equal @company.agents.count - 1, paused_count
  end

  test "does not pause terminated agents" do
    @company.agents.first.update_columns(status: Agent.statuses[:terminated])
    paused_count = EmergencyStopService.call!(company: @company, user: @user)
    assert paused_count < @company.agents.count
  end

  test "records audit event on company" do
    assert_difference -> { AuditEvent.where(action: "emergency_stop").count } do
      EmergencyStopService.call!(company: @company, user: @user)
    end
    audit = AuditEvent.where(action: "emergency_stop").last
    assert_equal @company.id, audit.company_id
    assert_equal @user.id, audit.actor_id
    assert_equal "User", audit.actor_type
  end

  test "creates notifications for owners and admins" do
    owner_admin_count = @company.memberships.where(role: [ :owner, :admin ]).count
    assert_difference -> { Notification.where(action: "emergency_stop").count }, owner_admin_count do
      EmergencyStopService.call!(company: @company, user: @user)
    end
    notification = Notification.where(action: "emergency_stop").last
    assert notification.metadata["agents_paused"].present?
    assert_equal @user.email_address, notification.metadata["triggered_by"]
  end

  test "does not affect agents in other companies" do
    widgets_agent = agents(:widgets_agent)
    widgets_agent.update_columns(status: Agent.statuses[:idle])
    EmergencyStopService.call!(company: @company, user: @user)
    widgets_agent.reload
    assert widgets_agent.idle?, "Widgets agent should not be affected"
  end
end
