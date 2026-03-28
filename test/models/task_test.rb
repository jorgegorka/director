require "test_helper"

class TaskTest < ActiveSupport::TestCase
  setup do
    @company = companies(:acme)
    @other_company = companies(:widgets)
    @user = users(:one)
    @agent = agents(:claude_agent)
    @task = tasks(:design_homepage)
  end

  # --- Validations ---

  test "valid with title, company, and creator" do
    task = Task.new(title: "New Task", company: @company, creator: @user)
    assert task.valid?
  end

  test "invalid without title" do
    task = Task.new(title: nil, company: @company, creator: @user)
    assert_not task.valid?
    assert_includes task.errors[:title], "can't be blank"
  end

  test "valid without assignee (unassigned task)" do
    task = Task.new(title: "Unassigned", company: @company, creator: @user)
    assert task.valid?
    assert_nil task.assignee
  end

  test "valid without parent_task (top-level task)" do
    task = Task.new(title: "Top Level", company: @company, creator: @user)
    assert task.valid?
    assert_nil task.parent_task
  end

  test "invalid when assignee belongs to different company" do
    other_agent = agents(:widgets_agent)
    task = Task.new(title: "Bad Assignee", company: @company, creator: @user, assignee: other_agent)
    assert_not task.valid?
    assert_includes task.errors[:assignee], "must belong to the same company"
  end

  test "invalid when parent_task belongs to different company" do
    other_task = tasks(:widgets_task)
    task = Task.new(title: "Bad Parent", company: @company, creator: @user, parent_task: other_task)
    assert_not task.valid?
    assert_includes task.errors[:parent_task], "must belong to the same company"
  end

  # --- Enums ---

  test "status enum: open?" do
    task = tasks(:fix_login_bug)
    assert task.open?
  end

  test "status enum: in_progress?" do
    assert @task.in_progress?
  end

  test "status enum: blocked?" do
    task = Task.new(status: :blocked)
    assert task.blocked?
  end

  test "status enum: completed?" do
    assert tasks(:completed_task).completed?
  end

  test "status enum: cancelled?" do
    task = Task.new(status: :cancelled)
    assert task.cancelled?
  end

  test "priority enum: low?" do
    assert tasks(:widgets_task).low?
  end

  test "priority enum: medium?" do
    assert tasks(:write_tests).medium?
  end

  test "priority enum: high?" do
    assert @task.high?
  end

  test "priority enum: urgent?" do
    assert tasks(:fix_login_bug).urgent?
  end

  # --- Associations ---

  test "belongs to company" do
    assert_equal @company, @task.company
  end

  test "belongs to creator (User)" do
    assert_equal users(:one), @task.creator
  end

  test "belongs to assignee (Agent, optional)" do
    assert_equal @agent, @task.assignee
    assert_nil tasks(:write_tests).assignee
  end

  test "belongs to parent_task (Task, optional)" do
    subtask = tasks(:subtask_one)
    assert_equal @task, subtask.parent_task
    assert_nil @task.parent_task
  end

  test "has many subtasks" do
    assert_includes @task.subtasks, tasks(:subtask_one)
  end

  test "has many messages" do
    assert @task.messages.count > 0
  end

  test "has many audit_events via Auditable" do
    assert @task.respond_to?(:audit_events)
    assert @task.respond_to?(:record_audit_event!)
  end

  # --- Scoping ---

  test "for_current_company returns only tasks in Current.company" do
    Current.company = @company
    tasks = Task.for_current_company
    assert_includes tasks, @task
    assert_not_includes tasks, tasks(:widgets_task)
  ensure
    Current.company = nil
  end

  test "active scope excludes completed and cancelled tasks" do
    active = Task.active
    assert_includes active, @task
    assert_not_includes active, tasks(:completed_task)
  end

  test "active scope excludes cancelled tasks" do
    cancelled = Task.create!(title: "Cancelled", company: @company, creator: @user, status: :cancelled)
    assert_not_includes Task.active, cancelled
  end

  test "by_priority scope sorts urgent first then by created_at desc" do
    urgent = tasks(:fix_login_bug)  # urgent priority
    high = @task                     # high priority
    Current.company = @company
    ordered = Task.for_current_company.by_priority.to_a
    urgent_index = ordered.index(urgent)
    high_index = ordered.index(high)
    assert_not_nil urgent_index, "urgent task should be in results"
    assert_not_nil high_index, "high priority task should be in results"
    assert urgent_index < high_index, "urgent should come before high priority"
  ensure
    Current.company = nil
  end

  test "roots scope excludes subtasks" do
    roots = Task.roots
    assert_includes roots, @task
    assert_not_includes roots, tasks(:subtask_one)
  end

  # --- Callbacks ---

  test "completing a task sets completed_at" do
    task = Task.create!(title: "Fresh Task", company: @company, creator: @user, status: :open)
    assert_nil task.completed_at
    task.update!(status: :completed)
    assert_not_nil task.completed_at
  end

  test "reopening a completed task clears completed_at" do
    task = tasks(:completed_task)
    assert_not_nil task.completed_at
    task.update!(status: :open)
    task.reload
    assert_nil task.completed_at
  end

  # --- Audit ---

  test "record_audit_event! creates an AuditEvent linked to the task" do
    assert_difference "AuditEvent.count", 1 do
      @task.record_audit_event!(actor: @user, action: "test_action", metadata: { key: "value" })
    end
    event = AuditEvent.last
    assert_equal @task, event.auditable
    assert_equal @user, event.actor
    assert_equal "test_action", event.action
  end

  # --- Deletion ---

  test "destroying task destroys its messages" do
    task = tasks(:design_homepage)
    msg_count = task.messages.count
    assert msg_count > 0
    assert_difference "Message.count", -msg_count do
      task.destroy
    end
  end

  test "destroying task destroys its subtasks" do
    subtask_count = @task.subtasks.count
    assert subtask_count > 0
    assert_difference "Task.count", -(subtask_count + 1) do
      @task.destroy
    end
  end

  test "destroying task destroys its audit_events" do
    @task.record_audit_event!(actor: @user, action: "test")
    event_count = @task.audit_events.count
    assert event_count > 0
    assert_difference "AuditEvent.count", -event_count do
      @task.destroy
    end
  end

  test "destroying company destroys its tasks" do
    task_count = @company.tasks.count
    assert task_count > 0
    assert_difference "Task.count", -task_count do
      @company.destroy
    end
  end

  test "destroying agent nullifies assignee_id" do
    task = tasks(:design_homepage)
    assert_not_nil task.assignee_id
    agents(:claude_agent).destroy
    task.reload
    assert_nil task.assignee_id
  end

  test "destroying user nullifies creator_id" do
    task = tasks(:write_tests)
    assert_not_nil task.creator_id
    users(:two).destroy
    task.reload
    assert_nil task.creator_id
  end

  # --- Cost ---

  test "valid with cost_cents" do
    task = tasks(:design_homepage)
    task.cost_cents = 5000
    assert task.valid?
  end

  test "valid with nil cost_cents" do
    task = tasks(:write_tests)
    task.cost_cents = nil
    assert task.valid?
  end

  test "invalid with negative cost_cents" do
    task = tasks(:design_homepage)
    task.cost_cents = -100
    assert_not task.valid?
    assert_includes task.errors[:cost_cents], "must be greater than or equal to 0"
  end

  test "valid with zero cost_cents" do
    task = tasks(:design_homepage)
    task.cost_cents = 0
    assert task.valid?
  end

  test "cost_in_dollars returns dollar amount" do
    task = tasks(:design_homepage)
    task.cost_cents = 1500
    assert_equal 15.0, task.cost_in_dollars
  end

  test "cost_in_dollars returns nil when cost_cents is nil" do
    task = tasks(:write_tests)
    task.cost_cents = nil
    assert_nil task.cost_in_dollars
  end

  # --- Real-time broadcasts ---

  test "task has broadcast_kanban_update private method" do
    assert @task.respond_to?(:broadcast_kanban_update, true)
  end

  test "task status change does not error" do
    assert_nothing_raised do
      @task.update!(status: :completed)
    end
  end
end
