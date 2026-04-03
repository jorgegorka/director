require "test_helper"

class Tasks::ApprovalsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @task = tasks(:design_homepage)
    sign_in_as @user
  end

  test "approve transitions pending_review task to completed" do
    @task.update!(status: :pending_review)

    patch task_approval_path(@task)
    @task.reload

    assert @task.completed?
    assert_not_nil @task.reviewed_at
    assert_redirected_to @task
  end

  test "approve records audit event" do
    @task.update!(status: :pending_review)

    assert_difference -> { AuditEvent.count }, 1 do
      patch task_approval_path(@task)
    end

    event = AuditEvent.last
    assert_equal "approved", event.action
  end

  test "approve fails on non-pending_review task" do
    @task.update!(status: :open)

    patch task_approval_path(@task)
    @task.reload

    assert @task.open?
    assert_redirected_to @task
    assert_equal "Task is not pending review.", flash[:alert]
  end
end
