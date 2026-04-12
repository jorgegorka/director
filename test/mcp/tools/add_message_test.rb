require "test_helper"

class Tools::AddMessageTest < ActiveSupport::TestCase
  setup do
    @ceo = roles(:ceo)
    @cto = roles(:cto)
    @developer = roles(:developer)
    @cmo = roles(:cmo)
    @project = projects(:acme)
  end

  test "assignee can post on own task" do
    task = Task.create!(title: "Own task", project: @project, creator: @ceo, assignee: @cto, status: :in_progress)
    tool = Tools::AddMessage.new(@cto)

    result = tool.call({ "task_id" => task.id, "message" => "update from assignee" })

    assert_equal task.id, result[:task_id]
    assert_equal "comment", result[:message_type]
    assert_equal 1, task.messages.count
  end

  test "creator can post on task they created" do
    task = Task.create!(title: "Delegated task", project: @project, creator: @ceo, assignee: @cto, status: :in_progress)
    tool = Tools::AddMessage.new(@ceo)

    result = tool.call({ "task_id" => task.id, "message" => "note from creator" })

    assert_equal task.id, result[:task_id]
    assert_equal 1, task.messages.count
  end

  test "unrelated role is rejected with actionable error" do
    task = Task.create!(title: "Private task", project: @project, creator: @ceo, assignee: @cto, status: :in_progress)
    tool = Tools::AddMessage.new(@cmo)

    error = assert_raises(ArgumentError) do
      tool.call({ "task_id" => task.id, "message" => "butting in" })
    end
    assert_match(/ancestors of a task you're assigned to/, error.message)
    assert_equal 0, task.messages.count
  end

  test "role assigned to a direct subtask can post on the parent task" do
    parent = Task.create!(title: "Parent mission", project: @project, creator: @ceo, assignee: @cto, status: :in_progress)
    Task.create!(title: "Child subtask", project: @project, creator: @cto, assignee: @developer, parent_task: parent, status: :in_progress)
    tool = Tools::AddMessage.new(@developer)

    result = tool.call({ "task_id" => parent.id, "message" => "status update for the parent mission" })

    assert_equal parent.id, result[:task_id]
    assert_equal 1, parent.messages.count
  end

  test "role assigned to a deep subtask can post on a transitive ancestor" do
    root = Task.create!(title: "Root mission", project: @project, creator: @ceo, assignee: @ceo, status: :in_progress)
    mid = Task.create!(title: "Mid task", project: @project, creator: @ceo, assignee: @cto, parent_task: root, status: :in_progress)
    Task.create!(title: "Leaf task", project: @project, creator: @cto, assignee: @developer, parent_task: mid, status: :in_progress)
    tool = Tools::AddMessage.new(@developer)

    result = tool.call({ "task_id" => root.id, "message" => "reporting up the chain" })

    assert_equal root.id, result[:task_id]
    assert_equal 1, root.messages.count
  end

  test "role cannot post on ancestor via a completed assignment" do
    parent = Task.create!(title: "Parent mission", project: @project, creator: @ceo, assignee: @cto, status: :in_progress)
    Task.create!(title: "Done child", project: @project, creator: @cto, assignee: @developer, parent_task: parent, status: :completed)
    tool = Tools::AddMessage.new(@developer)

    error = assert_raises(ArgumentError) do
      tool.call({ "task_id" => parent.id, "message" => "late note" })
    end
    assert_match(/ancestors of a task you're assigned to/, error.message)
    assert_equal 0, parent.messages.count
  end

  test "role cannot post on a sibling task" do
    parent = Task.create!(title: "Parent mission", project: @project, creator: @ceo, assignee: @ceo, status: :in_progress)
    sibling_a = Task.create!(title: "Sibling A", project: @project, creator: @ceo, assignee: @developer, parent_task: parent, status: :in_progress)
    sibling_b = Task.create!(title: "Sibling B", project: @project, creator: @ceo, assignee: @cto, parent_task: parent, status: :in_progress)
    tool = Tools::AddMessage.new(@developer)

    error = assert_raises(ArgumentError) do
      tool.call({ "task_id" => sibling_b.id, "message" => "cross-branch note" })
    end
    assert_match(/ancestors of a task you're assigned to/, error.message)
    assert_equal 0, sibling_b.messages.count
    assert_predicate sibling_a, :persisted?
  end

  test "role cannot post on a task in a different project" do
    other_project = projects(:widgets)
    other_role = roles(:widgets_lead)
    foreign_task = Task.create!(title: "Foreign task", project: other_project, creator: other_role, assignee: other_role, status: :in_progress)
    tool = Tools::AddMessage.new(@cto)

    assert_raises(ActiveRecord::RecordNotFound) do
      tool.call({ "task_id" => foreign_task.id, "message" => "poking across tenants" })
    end
    assert_equal 0, foreign_task.messages.count
  end
end
