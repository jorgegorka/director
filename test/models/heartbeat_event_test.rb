require "test_helper"

class HeartbeatEventTest < ActiveSupport::TestCase
  # Validations

  test "valid with role, trigger_type, and status" do
    event = HeartbeatEvent.new(
      role: roles(:cto),
      trigger_type: :scheduled,
      status: :queued
    )
    assert event.valid?
  end

  test "belongs to role" do
    assert_equal roles(:cto), heartbeat_events(:scheduled_heartbeat).role
  end

  # Enums

  test "trigger_type enum: scheduled?" do
    assert heartbeat_events(:scheduled_heartbeat).scheduled?
  end

  test "trigger_type enum: task_assigned?" do
    assert heartbeat_events(:task_assigned_event).task_assigned?
  end

  test "trigger_type enum: mention?" do
    assert heartbeat_events(:mention_event).mention?
  end

  test "trigger_type enum: hook_triggered?" do
    event = HeartbeatEvent.new(
      role: roles(:cto),
      trigger_type: :hook_triggered,
      status: :queued
    )
    assert event.hook_triggered?
  end

  test "status enum: queued?" do
    assert heartbeat_events(:queued_event).queued?
  end

  test "status enum: delivered?" do
    assert heartbeat_events(:scheduled_heartbeat).delivered?
  end

  test "status enum: failed?" do
    assert heartbeat_events(:failed_event).failed?
  end

  # Scopes

  test "chronological orders by created_at" do
    events = HeartbeatEvent.chronological
    timestamps = events.map(&:created_at)
    assert_equal timestamps, timestamps.sort
  end

  test "reverse_chronological orders newest first" do
    events = HeartbeatEvent.reverse_chronological
    timestamps = events.map(&:created_at)
    assert_equal timestamps, timestamps.sort.reverse
  end

  test "by_trigger filters by trigger_type" do
    scheduled = HeartbeatEvent.by_trigger(:scheduled)
    assert scheduled.all?(&:scheduled?)
    assert scheduled.count >= 1
  end

  test "for_role filters by role" do
    cto = roles(:cto)
    events = HeartbeatEvent.for_role(cto)
    assert events.all? { |e| e.role_id == cto.id }
    assert events.map(&:id).include?(heartbeat_events(:scheduled_heartbeat).id)
  end

  # Methods

  test "mark_delivered! updates status and delivered_at" do
    event = heartbeat_events(:queued_event)
    assert event.queued?
    assert_nil event.delivered_at

    event.mark_delivered!(response: { status: "ok" })
    assert event.delivered?
    assert_not_nil event.delivered_at
    assert_equal "ok", event.response_payload["status"]
  end

  test "mark_failed! updates status and records error" do
    event = heartbeat_events(:queued_event)
    event.mark_failed!(error_message: "timeout")
    assert event.failed?
    assert_equal "timeout", event.metadata["error"]
  end

  test "destroying role destroys heartbeat_events" do
    role = roles(:cto)
    event_ids = role.heartbeat_events.pluck(:id)
    assert event_ids.any?

    role.destroy
    assert_empty HeartbeatEvent.where(id: event_ids)
  end

  # Role association tests

  test "role.heartbeat_events returns associated events" do
    cto = roles(:cto)
    assert cto.heartbeat_events.map(&:id).include?(heartbeat_events(:scheduled_heartbeat).id)
  end

  test "role.heartbeat_scheduled? returns true when enabled with interval" do
    role = roles(:developer)
    role.heartbeat_enabled = true
    role.heartbeat_interval = 15
    assert role.heartbeat_scheduled?
  end

  test "role.heartbeat_scheduled? returns false when disabled" do
    role = roles(:developer)
    role.heartbeat_enabled = false
    role.heartbeat_interval = 15
    assert_not role.heartbeat_scheduled?
  end

  test "role.heartbeat_scheduled? returns false when interval nil" do
    role = roles(:developer)
    role.heartbeat_enabled = true
    role.heartbeat_interval = nil
    assert_not role.heartbeat_scheduled?
  end

  test "role validates heartbeat_interval is positive integer" do
    role = roles(:developer)

    role.heartbeat_interval = -5
    assert_not role.valid?

    role.heartbeat_interval = 0
    assert_not role.valid?

    role.heartbeat_interval = 15
    assert role.valid?
  end

  test "role reverse_chronological heartbeat events returns most recent first" do
    cto = roles(:cto)
    events = cto.heartbeat_events.reverse_chronological
    assert events.first.created_at >= events.last.created_at
  end
end
