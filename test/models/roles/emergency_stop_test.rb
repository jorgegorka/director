require "test_helper"

class Roles::EmergencyStopTest < ActiveSupport::TestCase
  setup do
    @project = projects(:acme)
    @user = users(:one)
    # Reset role statuses for clean tests
    @project.roles.where.not(adapter_type: nil).update_all(status: Role.statuses[:idle], pause_reason: nil, paused_at: nil)
  end

  test "pauses all active agent-configured roles in the project" do
    paused_count = Roles::EmergencyStop.call!(project: @project, user: @user)
    assert paused_count > 0
    @project.roles.where.not(adapter_type: nil).reload.each do |role|
      assert role.paused?, "Expected #{role.title} to be paused"
      assert_equal Roles::EmergencyStop::PAUSE_REASON, role.pause_reason
    end
  end

  test "returns count of roles paused" do
    active_count = @project.roles.active.where.not(adapter_type: nil).where.not(status: [ :paused, :terminated ]).count
    paused_count = Roles::EmergencyStop.call!(project: @project, user: @user)
    assert_equal active_count, paused_count
  end

  test "does not pause already-paused roles" do
    agent_roles = @project.roles.where.not(adapter_type: nil)
    agent_roles.first.update_columns(status: Role.statuses[:paused], pause_reason: "Manual pause")
    paused_count = Roles::EmergencyStop.call!(project: @project, user: @user)
    assert_equal agent_roles.count - 1, paused_count
  end

  test "does not pause terminated roles" do
    agent_roles = @project.roles.where.not(adapter_type: nil)
    agent_roles.first.update_columns(status: Role.statuses[:terminated])
    paused_count = Roles::EmergencyStop.call!(project: @project, user: @user)
    assert paused_count < agent_roles.count
  end

  test "records audit event on project" do
    assert_difference -> { AuditEvent.where(action: "emergency_stop").count } do
      Roles::EmergencyStop.call!(project: @project, user: @user)
    end
    audit = AuditEvent.where(action: "emergency_stop").last
    assert_equal @project.id, audit.project_id
    assert_equal @user.id, audit.actor_id
    assert_equal "User", audit.actor_type
  end

  test "creates notifications for owners and admins" do
    owner_admin_count = @project.memberships.where(role: [ :owner, :admin ]).count
    assert_difference -> { Notification.where(action: "emergency_stop").count }, owner_admin_count do
      Roles::EmergencyStop.call!(project: @project, user: @user)
    end
    notification = Notification.where(action: "emergency_stop").last
    assert notification.metadata["roles_paused"].present?
    assert_equal @user.email_address, notification.metadata["triggered_by"]
  end

  test "does not affect roles in other projects" do
    widgets_lead = roles(:widgets_lead)
    widgets_lead.update_columns(status: Role.statuses[:idle])
    Roles::EmergencyStop.call!(project: @project, user: @user)
    widgets_lead.reload
    assert widgets_lead.idle?, "Widgets role should not be affected"
  end
end
