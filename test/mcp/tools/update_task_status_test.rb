require "test_helper"

class Tools::UpdateTaskStatusTest < ActiveSupport::TestCase
  setup do
    @ceo = roles(:ceo)
    @cto = roles(:cto)
    @company = companies(:acme)
  end

  test "assignee can set task to in_progress" do
    task = Task.create!(title: "Test", company: @company, creator: @ceo, assignee: @cto, status: :open)
    tool = Tools::UpdateTaskStatus.new(@cto)

    result = tool.call({ "task_id" => task.id, "status" => "in_progress" })
    assert_equal "in_progress", result[:status]
  end

  test "assignee can submit task for review" do
    task = Task.create!(title: "Test", company: @company, creator: @ceo, assignee: @cto, status: :in_progress)
    tool = Tools::UpdateTaskStatus.new(@cto)

    result = tool.call({ "task_id" => task.id, "status" => "pending_review" })
    assert_equal "pending_review", result[:status]
  end

  test "creator can approve task" do
    task = Task.create!(title: "Test", company: @company, creator: @ceo, assignee: @cto, status: :pending_review)
    tool = Tools::UpdateTaskStatus.new(@ceo)

    result = tool.call({ "task_id" => task.id, "status" => "completed" })
    assert_equal "completed", result[:status]

    task.reload
    assert_equal @ceo, task.reviewed_by
    assert_not_nil task.reviewed_at
  end

  test "creator can reject task with feedback" do
    task = Task.create!(title: "Test", company: @company, creator: @ceo, assignee: @cto, status: :pending_review)
    tool = Tools::UpdateTaskStatus.new(@ceo)

    result = tool.call({ "task_id" => task.id, "status" => "open", "feedback" => "Needs more work" })
    assert_equal "open", result[:status]

    message = task.messages.last
    assert_equal "Needs more work", message.body
    assert_equal @ceo, message.author
  end

  test "non-assignee cannot submit for review" do
    task = Task.create!(title: "Test", company: @company, creator: @ceo, assignee: @cto, status: :in_progress)
    tool = Tools::UpdateTaskStatus.new(@ceo) # CEO is creator, not assignee

    assert_raises(ArgumentError) do
      tool.call({ "task_id" => task.id, "status" => "pending_review" })
    end
  end

  test "non-creator cannot approve" do
    task = Task.create!(title: "Test", company: @company, creator: @ceo, assignee: @cto, status: :pending_review)
    tool = Tools::UpdateTaskStatus.new(@cto) # CTO is assignee, not creator

    assert_raises(ArgumentError) do
      tool.call({ "task_id" => task.id, "status" => "completed" })
    end
  end
end
