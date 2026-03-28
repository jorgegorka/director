require "test_helper"

class AuditEventTest < ActiveSupport::TestCase
  setup do
    @task = tasks(:design_homepage)
    @user = users(:one)
    @agent = agents(:claude_agent)
    @event = audit_events(:task_created)
  end

  # --- Validations ---

  test "valid with auditable, actor, and action" do
    event = AuditEvent.new(auditable: @task, actor: @user, action: "created")
    assert event.valid?
  end

  test "invalid without action" do
    event = AuditEvent.new(auditable: @task, actor: @user, action: nil)
    assert_not event.valid?
    assert_includes event.errors[:action], "can't be blank"
  end

  # --- Associations ---

  test "belongs to auditable (polymorphic) - Task" do
    assert_equal @task, @event.auditable
    assert_equal "Task", @event.auditable_type
  end

  test "belongs to actor (polymorphic) - User" do
    assert_equal @user, @event.actor
    assert_equal "User", @event.actor_type
  end

  test "belongs to actor (polymorphic) - Agent" do
    agent_event = audit_events(:task_status_changed)
    assert_equal @agent, agent_event.actor
    assert_equal "Agent", agent_event.actor_type
  end

  # --- Immutability ---

  test "persisted audit event is readonly" do
    assert @event.persisted?
    assert @event.readonly?
    assert_raises ActiveRecord::ReadOnlyRecord do
      @event.save
    end
  end

  test "new audit events can be saved" do
    event = AuditEvent.new(auditable: @task, actor: @user, action: "new_action")
    assert_not event.readonly?
    assert event.save
  end

  # --- Scopes ---

  test "chronological returns oldest first" do
    events = AuditEvent.where(auditable: @task).chronological
    assert events.first.created_at <= events.last.created_at if events.count > 1
  end

  test "reverse_chronological returns newest first" do
    events = AuditEvent.where(auditable: @task).reverse_chronological
    assert events.first.created_at >= events.last.created_at if events.count > 1
  end

  test "for_action filters by action string" do
    created_events = AuditEvent.for_action("created")
    assert_includes created_events, audit_events(:task_created)
    assert_not_includes created_events, audit_events(:task_assigned)
  end

  # --- Metadata ---

  test "metadata is a hash" do
    assert_kind_of Hash, @event.metadata
  end

  test "metadata stores before/after state correctly" do
    event = audit_events(:task_status_changed)
    assert_equal "open", event.metadata["from"]
    assert_equal "in_progress", event.metadata["to"]
  end

  # --- Company scoping ---

  test "for_company returns events for specified company" do
    company = companies(:acme)
    events = AuditEvent.for_company(company)
    events.each { |e| assert_equal company.id, e.company_id }
  end

  test "for_actor_type filters by actor type" do
    events = AuditEvent.for_actor_type("User")
    events.each { |e| assert_equal "User", e.actor_type }
  end

  test "for_date_range filters by date" do
    start_date = 1.week.ago.to_date
    end_date = Date.current
    events = AuditEvent.for_date_range(start_date, end_date)
    events.each do |e|
      assert e.created_at >= start_date.beginning_of_day
      assert e.created_at <= end_date.end_of_day
    end
  end

  test "governance_action? returns true for governance actions" do
    event = audit_events(:gate_approval_event)
    assert event.governance_action?
  end

  test "governance_action? returns false for regular actions" do
    event = audit_events(:task_created)
    assert_not event.governance_action?
  end

  test "GOVERNANCE_ACTIONS includes expected action types" do
    expected = %w[gate_approval gate_rejection emergency_stop emergency_resume agent_paused agent_resumed agent_terminated config_rollback cost_recorded hook_executed]
    expected.each do |action|
      assert_includes AuditEvent::GOVERNANCE_ACTIONS, action
    end
  end

  # --- Real-time broadcasts ---

  test "audit event has broadcast_activity_event private method" do
    event = AuditEvent.new(
      auditable: agents(:claude_agent),
      actor: users(:one),
      action: "test_action",
      company: companies(:acme)
    )
    assert event.respond_to?(:broadcast_activity_event, true)
  end

  test "creating audit event does not error" do
    assert_nothing_raised do
      AuditEvent.create!(
        auditable: agents(:claude_agent),
        actor: users(:one),
        action: "test_broadcast",
        company: companies(:acme)
      )
    end
  end
end
