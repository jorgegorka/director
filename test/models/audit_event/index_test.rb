require "test_helper"

class AuditEvent::IndexTest < ActiveSupport::TestCase
  setup do
    @project = projects(:acme)
  end

  # --- Events ---

  test "events returns audit events for the project" do
    index = AuditEvent::Index.new(@project)
    assert index.events.any?
    index.events.each do |event|
      assert_equal @project.id, event.project_id
    end
  end

  test "events are in reverse chronological order" do
    index = AuditEvent::Index.new(@project)
    events = index.events
    if events.size > 1
      events.each_cons(2) do |newer, older|
        assert newer.created_at >= older.created_at
      end
    end
  end

  test "events limited to 100" do
    index = AuditEvent::Index.new(@project)
    assert index.events.size <= 100
  end

  # --- Filtering ---

  test "filters by actor_type" do
    index = AuditEvent::Index.new(@project, actor_type: "User")
    index.events.each do |event|
      assert_equal "User", event.actor_type
    end
  end

  test "filters by action" do
    index = AuditEvent::Index.new(@project, action_filter: "created")
    index.events.each do |event|
      assert_equal "created", event.action
    end
  end

  test "filters by date range" do
    start_date = 1.week.ago.to_date.to_s
    end_date = Date.current.to_s
    index = AuditEvent::Index.new(@project, start_date: start_date, end_date: end_date)
    index.events.each do |event|
      assert event.created_at >= 1.week.ago.to_date.beginning_of_day
      assert event.created_at <= Date.current.end_of_day
    end
  end

  test "returns all events with no filters" do
    index = AuditEvent::Index.new(@project)
    all_events = AuditEvent.for_project(@project)
    assert_equal all_events.count, index.events.size
  end

  test "ignores date range when only start_date provided" do
    index = AuditEvent::Index.new(@project, start_date: Date.current.to_s)
    all_count = AuditEvent.for_project(@project).count
    assert_equal all_count, index.events.size
  end

  test "ignores date range when only end_date provided" do
    index = AuditEvent::Index.new(@project, end_date: Date.current.to_s)
    all_count = AuditEvent.for_project(@project).count
    assert_equal all_count, index.events.size
  end

  # --- Available actions and actor types ---

  test "available_actions returns sorted distinct actions" do
    index = AuditEvent::Index.new(@project)
    actions = index.available_actions
    assert actions.any?
    assert_equal actions.sort, actions
    assert_equal actions.uniq, actions
  end

  test "available_actor_types returns sorted distinct actor types" do
    index = AuditEvent::Index.new(@project)
    types = index.available_actor_types
    assert types.any?
    assert_equal types.sort, types
    assert_equal types.uniq, types
    assert_not_includes types, nil
  end

  # --- Boolean helpers ---

  test "filtered? returns false with no filters" do
    index = AuditEvent::Index.new(@project)
    assert_not index.filtered?
  end

  test "filtered? returns true with actor_type filter" do
    index = AuditEvent::Index.new(@project, actor_type: "User")
    assert index.filtered?
  end

  test "filtered? returns true with action_filter" do
    index = AuditEvent::Index.new(@project, action_filter: "created")
    assert index.filtered?
  end

  test "filtered? returns true with date range" do
    index = AuditEvent::Index.new(@project, start_date: "2025-01-01", end_date: "2025-12-31")
    assert index.filtered?
  end

  test "any_events? returns true when events exist" do
    index = AuditEvent::Index.new(@project)
    assert index.any_events?
  end

  test "any_events? returns false when no events match" do
    index = AuditEvent::Index.new(@project, action_filter: "nonexistent_action_xyz")
    assert_not index.any_events?
  end

  # --- Filter accessors ---

  test "actor_type_filter returns the filter value" do
    index = AuditEvent::Index.new(@project, actor_type: "User")
    assert_equal "User", index.actor_type_filter
  end

  test "action_filter returns the filter value" do
    index = AuditEvent::Index.new(@project, action_filter: "created")
    assert_equal "created", index.action_filter
  end

  test "start_date returns the filter value" do
    index = AuditEvent::Index.new(@project, start_date: "2025-01-01")
    assert_equal "2025-01-01", index.start_date
  end

  test "end_date returns the filter value" do
    index = AuditEvent::Index.new(@project, end_date: "2025-12-31")
    assert_equal "2025-12-31", index.end_date
  end

  test "filter accessors return nil when not set" do
    index = AuditEvent::Index.new(@project)
    assert_nil index.actor_type_filter
    assert_nil index.action_filter
    assert_nil index.start_date
    assert_nil index.end_date
  end
end
