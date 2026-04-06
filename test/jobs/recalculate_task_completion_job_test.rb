require "test_helper"

class RecalculateTaskCompletionJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @project = projects(:acme)
    @ceo = roles(:ceo)
  end

  test "recalculates completion percentage from subtasks" do
    parent = Task.create!(title: "Parent", project: @project, creator: @ceo, status: :open)
    Task.create!(title: "Done", project: @project, creator: @ceo, parent_task: parent, status: :completed)
    Task.create!(title: "Open", project: @project, creator: @ceo, parent_task: parent, status: :open)

    RecalculateTaskCompletionJob.perform_now(parent.id)
    assert_equal 50, parent.reload.completion_percentage
  end

  test "cascades up to parent task" do
    grandparent = Task.create!(title: "Grandparent", project: @project, creator: @ceo, status: :open)
    parent = Task.create!(title: "Parent", project: @project, creator: @ceo, parent_task: grandparent, status: :open)
    Task.create!(title: "Sub", project: @project, creator: @ceo, parent_task: parent, status: :completed)

    assert_enqueued_with(job: RecalculateTaskCompletionJob, args: [ grandparent.id ]) do
      RecalculateTaskCompletionJob.perform_now(parent.id)
    end
  end

  test "handles deleted task gracefully" do
    assert_nothing_raised do
      RecalculateTaskCompletionJob.perform_now(0)
    end
  end

  test "does not cascade when no parent" do
    parent = Task.create!(title: "Root", project: @project, creator: @ceo, status: :open)
    Task.create!(title: "Sub", project: @project, creator: @ceo, parent_task: parent, status: :completed)

    assert_no_enqueued_jobs(only: RecalculateTaskCompletionJob) do
      RecalculateTaskCompletionJob.perform_now(parent.id)
    end
  end
end
