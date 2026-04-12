require "test_helper"

class Tools::SubmitReviewDecisionTest < ActiveSupport::TestCase
  setup do
    # cto created fix_login_bug; flip it to pending_review so cto (as
    # creator) is the reviewer under test.
    @task = tasks(:fix_login_bug)
    @task.update_columns(status: Task.statuses[:pending_review])
    @role = roles(:cto)
    @tool = Tools::SubmitReviewDecision.new(@role)
  end

  test "approve transitions to completed and records reviewer" do
    result = @tool.call({ "task_id" => @task.id, "decision" => "approve" })
    assert_equal "approved", result[:decision]

    @task.reload
    assert @task.completed?
    assert_equal @role, @task.reviewed_by
    assert_not_nil @task.reviewed_at
  end

  test "reject transitions to open and posts feedback message" do
    assert_difference -> { @task.messages.count }, +1 do
      @tool.call({
        "task_id" => @task.id,
        "decision" => "reject",
        "feedback" => "The escape logic is missing for backslash characters."
      })
    end

    assert @task.reload.open?
    message = @task.messages.order(:id).last
    assert_equal @role, message.author
    assert_match(/backslash/, message.body)
  end

  test "reject without feedback raises ArgumentError so the claude CLI sees the tool error" do
    assert_raises(ArgumentError) do
      @tool.call({ "task_id" => @task.id, "decision" => "reject", "feedback" => "" })
    end
  end

  test "non-creator cannot approve" do
    other_role = roles(:ceo)
    other_tool = Tools::SubmitReviewDecision.new(other_role)

    assert_raises(ArgumentError) do
      other_tool.call({ "task_id" => @task.id, "decision" => "approve" })
    end
  end

  test "task not pending review cannot be approved" do
    @task.update_columns(status: Task.statuses[:open])

    assert_raises(ArgumentError) do
      @tool.call({ "task_id" => @task.id, "decision" => "approve" })
    end
  end

  test "approving the final pending subtask returns root_task_completed hint" do
    # Build a root task with @task as its only subtask; approving it brings
    # the root to 100%.
    root = Task.create!(title: "Root mission", project: @task.project, creator: roles(:ceo), assignee: @role, status: :in_progress)
    @task.update_columns(parent_task_id: root.id)

    result = @tool.call({ "task_id" => @task.id, "decision" => "approve" })

    assert_equal "approved", result[:decision]
    assert_equal({ id: root.id, title: root.title }, result[:root_task_completed])
  end

  test "approving a non-final subtask does not include root_task_completed hint" do
    root = Task.create!(title: "Root mission", project: @task.project, creator: roles(:ceo), assignee: @role, status: :in_progress)
    Task.create!(title: "Sibling still running", project: @task.project, creator: @role, assignee: @role, parent_task: root, status: :in_progress)
    @task.update_columns(parent_task_id: root.id)

    result = @tool.call({ "task_id" => @task.id, "decision" => "approve" })

    assert_equal "approved", result[:decision]
    assert_nil result[:root_task_completed]
  end

  test "approving a root task (no parent) does not include root_task_completed hint" do
    # @task has no parent, so there is no root ancestor to complete.
    result = @tool.call({ "task_id" => @task.id, "decision" => "approve" })

    assert_nil result[:root_task_completed]
  end
end
