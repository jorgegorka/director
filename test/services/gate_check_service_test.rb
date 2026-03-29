require "test_helper"

class GateCheckServiceTest < ActiveSupport::TestCase
  setup do
    @role = roles(:cto)
    @company = companies(:acme)
    # cto has task_creation and budget_spend gates enabled in fixtures
  end

  test "returns false and pauses role when gate is active" do
    result = GateCheckService.check!(role: @role, action_type: "task_creation")
    assert_equal false, result
    @role.reload
    assert @role.pending_approval?
    assert_match /Approval required/, @role.pause_reason
  end

  test "returns true when no gate exists for action type" do
    result = GateCheckService.check!(role: @role, action_type: "status_change")
    assert_equal true, result
    @role.reload
    assert_not @role.pending_approval?
  end

  test "returns true when gate exists but is disabled" do
    result = GateCheckService.check!(role: @role, action_type: "task_delegation")
    assert_equal true, result
    @role.reload
    assert_not @role.pending_approval?
  end

  test "creates notification for owners/admins when gate blocks" do
    Notification.where(notifiable: @role, action: "gate_pending_approval").delete_all
    assert_difference -> { Notification.where(action: "gate_pending_approval").count } do
      GateCheckService.check!(role: @role, action_type: "task_creation")
    end
    notification = Notification.where(notifiable: @role, action: "gate_pending_approval").last
    assert_equal "task_creation", notification.metadata["action_type"]
    assert_equal @role.title, notification.metadata["agent_name"]
  end

  test "records audit event when gate blocks" do
    assert_difference -> { AuditEvent.where(action: "gate_blocked").count } do
      GateCheckService.check!(role: @role, action_type: "task_creation")
    end
    audit = AuditEvent.where(action: "gate_blocked").last
    assert_equal "task_creation", audit.metadata["action_type"]
    assert_equal @company.id, audit.company_id
  end

  test "does not pause terminated role" do
    @role.update_columns(status: Role.statuses[:terminated])
    result = GateCheckService.check!(role: @role, action_type: "task_creation")
    assert_equal true, result
  end

  test "passes context to notification metadata" do
    Notification.where(notifiable: @role, action: "gate_pending_approval").delete_all
    GateCheckService.check!(role: @role, action_type: "budget_spend", context: { amount: 5000 })
    notification = Notification.where(notifiable: @role, action: "gate_pending_approval").last
    assert_equal({ "amount" => 5000 }, notification.metadata["context"])
  end

  test "returns true for role with no gates at all" do
    role = roles(:process_role)
    result = GateCheckService.check!(role: role, action_type: "task_creation")
    assert_equal true, result
  end
end
