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
end
