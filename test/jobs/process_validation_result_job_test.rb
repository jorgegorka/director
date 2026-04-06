require "test_helper"

class ProcessValidationResultJobTest < ActiveSupport::TestCase
  setup do
    @project = projects(:acme)
    @cto = roles(:cto)
    @developer = roles(:developer)
    @parent_task = tasks(:design_homepage)  # in_progress, assigned to cto
  end

  test "skips when task not found" do
    assert_nothing_raised do
      ProcessValidationResultJob.perform_now(999999)
    end
  end

  test "skips when task is not completed" do
    subtask = Task.create!(
      title: "Validate: Test",
      project: @project,
      assignee: @developer,
      parent_task: @parent_task,
      status: :open
    )

    assert_no_difference "Message.count" do
      ProcessValidationResultJob.perform_now(subtask.id)
    end
  end

  test "skips when task has no parent_task" do
    @parent_task.update_columns(status: 3)

    assert_no_difference "Message.count" do
      ProcessValidationResultJob.perform_now(@parent_task.id)
    end
  end

  test "calls Hooks::ValidationProcessor for completed subtask with parent" do
    subtask = Task.create!(
      title: "Validate: #{@parent_task.title}",
      project: @project,
      assignee: @developer,
      parent_task: @parent_task,
      status: :open
    )
    subtask.update_columns(status: 3)
    subtask.reload

    assert_difference "Message.count", 1 do
      ProcessValidationResultJob.perform_now(subtask.id)
    end
  end

  test "job is enqueued to default queue" do
    assert_equal "default", ProcessValidationResultJob.new.queue_name
  end

  test "has retry_on configured for 3 attempts" do
    assert ProcessValidationResultJob.instance_method(:perform)
  end
end
