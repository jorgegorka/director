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

  test "approving the final pending task returns goal_completed hint" do
    # Flip every other task on fix_login_bug's goal to completed so this
    # approval will leave the goal at 100%.
    goal = @task.goal
    goal.tasks.where.not(id: @task.id).update_all(status: Task.statuses[:completed])

    result = @tool.call({ "task_id" => @task.id, "decision" => "approve" })

    assert_equal "approved", result[:decision]
    assert_equal({ id: goal.id, title: goal.title }, result[:goal_completed])
  end

  test "approving a non-final task does not include goal_completed hint" do
    # Sibling task on the same goal is still in_progress, so approving
    # fix_login_bug should NOT bring the goal to 100%.
    other = tasks(:design_homepage)
    assert_equal @task.goal_id, other.goal_id
    refute other.completed?

    result = @tool.call({ "task_id" => @task.id, "decision" => "approve" })

    assert_equal "approved", result[:decision]
    assert_nil result[:goal_completed]
  end

  test "approving a task without a goal does not include goal_completed hint" do
    @task.update_columns(goal_id: nil)

    result = @tool.call({ "task_id" => @task.id, "decision" => "approve" })

    assert_nil result[:goal_completed]
  end
end
