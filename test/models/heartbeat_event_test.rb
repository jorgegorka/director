require "test_helper"

class HeartbeatEventTest < ActiveSupport::TestCase
  # Validations

  test "valid with agent, trigger_type, and status" do
    event = HeartbeatEvent.new(
      agent: agents(:claude_agent),
      trigger_type: :scheduled,
      status: :queued
    )
    assert event.valid?
  end

  test "belongs to agent" do
    assert_equal agents(:claude_agent), heartbeat_events(:scheduled_heartbeat).agent
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

  test "for_agent filters by agent" do
    claude = agents(:claude_agent)
    events = HeartbeatEvent.for_agent(claude)
    assert events.all? { |e| e.agent_id == claude.id }
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

  test "destroying agent destroys heartbeat_events" do
    agent = agents(:claude_agent)
    event_ids = agent.heartbeat_events.pluck(:id)
    assert event_ids.any?

    agent.destroy
    assert_empty HeartbeatEvent.where(id: event_ids)
  end

  # Agent association tests

  test "agent.heartbeat_events returns associated events" do
    claude = agents(:claude_agent)
    assert claude.heartbeat_events.map(&:id).include?(heartbeat_events(:scheduled_heartbeat).id)
  end

  test "agent.heartbeat_scheduled? returns true when enabled with interval" do
    agent = agents(:http_agent)
    agent.heartbeat_enabled = true
    agent.heartbeat_interval = 15
    assert agent.heartbeat_scheduled?
  end

  test "agent.heartbeat_scheduled? returns false when disabled" do
    agent = agents(:http_agent)
    agent.heartbeat_enabled = false
    agent.heartbeat_interval = 15
    assert_not agent.heartbeat_scheduled?
  end

  test "agent.heartbeat_scheduled? returns false when interval nil" do
    agent = agents(:http_agent)
    agent.heartbeat_enabled = true
    agent.heartbeat_interval = nil
    assert_not agent.heartbeat_scheduled?
  end

  test "agent validates heartbeat_interval is positive integer" do
    agent = agents(:http_agent)

    agent.heartbeat_interval = -5
    assert_not agent.valid?

    agent.heartbeat_interval = 0
    assert_not agent.valid?

    agent.heartbeat_interval = 15
    assert agent.valid?
  end

  test "agent reverse_chronological heartbeat events returns most recent first" do
    claude = agents(:claude_agent)
    events = claude.heartbeat_events.reverse_chronological
    assert events.first.created_at >= events.last.created_at
  end
end
