require "test_helper"

class Tasks::RejectionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @task = tasks(:design_homepage)
    sign_in_as @user
  end

  test "reject transitions pending_review task to open" do
    @task.update!(status: :pending_review)

    patch task_rejection_path(@task), params: { feedback: "Needs more detail" }
    @task.reload

    assert @task.open?
    assert_redirected_to @task
  end

  test "reject posts feedback as message" do
    @task.update!(status: :pending_review)

    assert_difference -> { Message.count }, 1 do
      patch task_rejection_path(@task), params: { feedback: "Needs more detail" }
    end

    message = @task.messages.last
    assert_equal "Needs more detail", message.body
  end

  test "reject without feedback does not create message" do
    @task.update!(status: :pending_review)

    assert_no_difference -> { Message.count } do
      patch task_rejection_path(@task)
    end

    assert @task.reload.open?
  end

  test "reject records audit event" do
    @task.update!(status: :pending_review)

    assert_difference -> { AuditEvent.count }, 1 do
      patch task_rejection_path(@task), params: { feedback: "Not good enough" }
    end

    event = AuditEvent.last
    assert_equal "rejected", event.action
    assert_equal "Not good enough", event.metadata["feedback"]
  end

  test "reject fails on non-pending_review task" do
    @task.update!(status: :open)

    patch task_rejection_path(@task)
    @task.reload

    assert @task.open?
    assert_redirected_to @task
    assert_equal "Task is not pending review.", flash[:alert]
  end
end
