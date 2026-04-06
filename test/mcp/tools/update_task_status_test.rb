require "test_helper"

class Tools::UpdateTaskStatusTest < ActiveSupport::TestCase
  setup do
    @ceo = roles(:ceo)
    @cto = roles(:cto)
    @project = projects(:acme)
  end

  test "assignee can set task to in_progress" do
    task = Task.create!(title: "Test", project: @project, creator: @ceo, assignee: @cto, status: :open)
    tool = Tools::UpdateTaskStatus.new(@cto)

    result = tool.call({ "task_id" => task.id, "status" => "in_progress" })
    assert_equal "in_progress", result[:status]
  end

  test "assignee can submit task for review" do
    task = Task.create!(title: "Test", project: @project, creator: @ceo, assignee: @cto, status: :in_progress)
    tool = Tools::UpdateTaskStatus.new(@cto)

    result = tool.call({ "task_id" => task.id, "status" => "pending_review" })
    assert_equal "pending_review", result[:status]
  end

  test "creator cannot approve via update_task_status -- must use review_task sub-agent" do
    task = Task.create!(title: "Test", project: @project, creator: @ceo, assignee: @cto, status: :pending_review)
    tool = Tools::UpdateTaskStatus.new(@ceo)

    error = assert_raises(ArgumentError) do
      tool.call({ "task_id" => task.id, "status" => "completed" })
    end
    assert_match(/review_task/, error.message)
  end

  test "creator cannot reject via update_task_status -- must use review_task sub-agent" do
    task = Task.create!(title: "Test", project: @project, creator: @ceo, assignee: @cto, status: :pending_review)
    tool = Tools::UpdateTaskStatus.new(@ceo)

    error = assert_raises(ArgumentError) do
      tool.call({ "task_id" => task.id, "status" => "open", "feedback" => "Needs more work" })
    end
    assert_match(/review_task/, error.message)
  end

  test "non-assignee cannot submit for review" do
    task = Task.create!(title: "Test", project: @project, creator: @ceo, assignee: @cto, status: :in_progress)
    tool = Tools::UpdateTaskStatus.new(@ceo) # CEO is creator, not assignee

    assert_raises(ArgumentError) do
      tool.call({ "task_id" => task.id, "status" => "pending_review" })
    end
  end

  test "assignee cannot submit for review with incomplete subtasks" do
    task = Task.create!(title: "Parent", project: @project, creator: @ceo, assignee: @cto, status: :in_progress)
    Task.create!(title: "Subtask", project: @project, creator: @cto, assignee: @cto, parent_task: task, status: :open)
    tool = Tools::UpdateTaskStatus.new(@cto)

    assert_raises(ArgumentError, "Cannot submit for review: 1 subtask(s) are not yet completed") do
      tool.call({ "task_id" => task.id, "status" => "pending_review" })
    end
  end

  test "assignee can submit for review when all subtasks are completed" do
    task = Task.create!(title: "Parent", project: @project, creator: @ceo, assignee: @cto, status: :in_progress)
    Task.create!(title: "Subtask", project: @project, creator: @cto, assignee: @cto, parent_task: task, status: :completed)
    tool = Tools::UpdateTaskStatus.new(@cto)

    result = tool.call({ "task_id" => task.id, "status" => "pending_review" })
    assert_equal "pending_review", result[:status]
  end

  test "completed status is rejected for all callers -- review goes through review_task" do
    task = Task.create!(title: "Test", project: @project, creator: @ceo, assignee: @cto, status: :pending_review)
    tool = Tools::UpdateTaskStatus.new(@cto) # CTO is assignee, not creator

    assert_raises(ArgumentError) do
      tool.call({ "task_id" => task.id, "status" => "completed" })
    end
  end
end
