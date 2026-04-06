require "test_helper"

class Hooks::ValidationProcessorTest < ActiveSupport::TestCase
  setup do
    @project = projects(:acme)
    @cto = roles(:cto)
    @developer = roles(:developer)
    @parent_task = tasks(:design_homepage)  # in_progress, assigned to cto

    # Create a completed validation subtask
    @validation_task = Task.create!(
      title: "Validate: #{@parent_task.title}",
      description: "Review the completed work.",
      project: @project,
      assignee: @developer,
      parent_task: @parent_task,
      status: :open
    )
    @validation_task.update_columns(status: 3)  # completed, bypass callbacks
    @validation_task.reload

    # Add messages to the validation subtask to simulate validation conversation
    @validation_msg1 = Message.create!(
      task: @validation_task,
      author: @developer,
      body: "I reviewed the homepage design. The layout looks good but the navigation needs work."
    )
    @validation_msg2 = Message.create!(
      task: @validation_task,
      author: @developer,
      body: "Specifically, the mobile menu is missing responsive breakpoints."
    )
  end

  # --- Feedback message creation ---

  test "posts feedback message on parent task" do
    assert_difference "Message.count", 1 do
      Hooks::ValidationProcessor.call(@validation_task)
    end

    feedback = @parent_task.messages.order(:created_at).last
    assert_equal @parent_task.id, feedback.task_id
  end

  test "feedback message author is the validation role" do
    Hooks::ValidationProcessor.call(@validation_task)
    feedback = @parent_task.messages.order(:created_at).last
    assert_equal @developer, feedback.author
  end

  test "feedback message body contains validation task title" do
    Hooks::ValidationProcessor.call(@validation_task)
    feedback = @parent_task.messages.order(:created_at).last
    assert_includes feedback.body, @validation_task.title
  end

  test "feedback message body contains validation messages" do
    Hooks::ValidationProcessor.call(@validation_task)
    feedback = @parent_task.messages.order(:created_at).last
    assert_includes feedback.body, "navigation needs work"
    assert_includes feedback.body, "mobile menu is missing"
  end

  test "feedback message body contains validation role title" do
    Hooks::ValidationProcessor.call(@validation_task)
    feedback = @parent_task.messages.order(:created_at).last
    assert_includes feedback.body, @developer.title
  end

  test "feedback message body handles no validation messages" do
    @validation_task.messages.delete_all

    Hooks::ValidationProcessor.call(@validation_task)
    feedback = @parent_task.messages.order(:created_at).last
    assert_includes feedback.body, "No messages were posted during validation"
  end

  # --- Role wake ---

  test "wakes parent task assignee with review_validation trigger" do
    assert_difference "HeartbeatEvent.count", 1 do
      Hooks::ValidationProcessor.call(@validation_task)
    end

    event = HeartbeatEvent.order(:created_at).last
    assert event.review_validation?
    assert_equal @cto.id, event.role_id
    assert_equal "Task##{@validation_task.id}", event.trigger_source
  end

  test "wake context includes validation and parent task IDs" do
    Hooks::ValidationProcessor.call(@validation_task)

    event = HeartbeatEvent.order(:created_at).last
    payload = event.request_payload
    assert_equal @validation_task.id, payload["validation_task_id"]
    assert_equal @parent_task.id, payload["parent_task_id"]
  end

  test "skips wake when parent task has no assignee" do
    @parent_task.update_columns(assignee_id: nil)

    assert_difference "Message.count", 1 do
      assert_no_difference "HeartbeatEvent.count" do
        Hooks::ValidationProcessor.call(@validation_task)
      end
    end
  end

  test "skips wake when parent task assignee is terminated" do
    @cto.update_columns(status: 4)  # terminated

    assert_difference "Message.count", 1 do
      assert_no_difference "HeartbeatEvent.count" do
        Hooks::ValidationProcessor.call(@validation_task)
      end
    end
  end

  # --- Audit event ---

  test "records validation_feedback_received audit event on parent task" do
    assert_difference "AuditEvent.count", 1 do
      Hooks::ValidationProcessor.call(@validation_task)
    end

    audit = AuditEvent.where(action: "validation_feedback_received").last
    assert_equal @parent_task, audit.auditable
    assert_equal @developer, audit.actor
    assert_equal @project, audit.project
    assert_equal @validation_task.id, audit.metadata["validation_task_id"]
    assert_equal @parent_task.id, audit.metadata["parent_task_id"]
  end

  test "audit event metadata includes message count" do
    Hooks::ValidationProcessor.call(@validation_task)

    audit = AuditEvent.where(action: "validation_feedback_received").last
    assert_equal 2, audit.metadata["message_count"]
  end

  # --- Edge cases ---

  test "returns nil when validation task has no parent" do
    orphan_task = Task.create!(
      title: "Orphan task",
      project: @project,
      assignee: @developer,
      status: :open
    )
    orphan_task.update_columns(status: 3)
    orphan_task.reload

    assert_no_difference [ "Message.count", "HeartbeatEvent.count", "AuditEvent.count" ] do
      Hooks::ValidationProcessor.call(orphan_task)
    end
  end

  test "returns nil when validation task is not completed" do
    @validation_task.update_columns(status: 1)  # in_progress
    @validation_task.reload

    assert_no_difference [ "Message.count", "HeartbeatEvent.count", "AuditEvent.count" ] do
      Hooks::ValidationProcessor.call(@validation_task)
    end
  end

  test "full flow: feedback posted, role woken, audit recorded in one call" do
    assert_difference "Message.count", 1 do
      assert_difference "HeartbeatEvent.count", 1 do
        assert_difference "AuditEvent.count", 1 do
          Hooks::ValidationProcessor.call(@validation_task)
        end
      end
    end
  end
end
