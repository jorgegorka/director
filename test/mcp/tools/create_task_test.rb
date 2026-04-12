require "test_helper"

class Tools::CreateTaskTest < ActiveSupport::TestCase
  setup do
    @ceo = roles(:ceo)
    @cto = roles(:cto)
    @developer = roles(:developer)
  end

  test "creates task assigned to subordinate" do
    tool = Tools::CreateTask.new(@ceo)

    result = tool.call({
      "title" => "New task from CEO",
      "description" => "Test task",
      "priority" => "high",
      "assignee_role_id" => @cto.id
    })

    assert result[:id].present?
    assert_equal "New task from CEO", result[:title]
    assert_equal "open", result[:status]
    assert_equal @cto.id, result[:assignee_id]

    task = Task.find(result[:id])
    assert_equal @ceo, task.creator
  end

  test "creates task assigned to sibling" do
    tool = Tools::CreateTask.new(@developer)

    result = tool.call({
      "title" => "Peer task",
      "assignee_role_id" => roles(:process_role).id
    })

    assert result[:id].present?
  end

  test "rejects task assigned to non-subordinate/sibling" do
    tool = Tools::CreateTask.new(@developer)

    assert_raises(ActiveRecord::RecordInvalid) do
      tool.call({
        "title" => "Bad assignment",
        "assignee_role_id" => @ceo.id
      })
    end
  end

  test "creates subtask" do
    tool = Tools::CreateTask.new(@ceo)
    parent = tasks(:design_homepage)

    result = tool.call({
      "title" => "Subtask",
      "parent_task_id" => parent.id,
      "assignee_role_id" => @cto.id
    })

    task = Task.find(result[:id])
    assert_equal parent, task.parent_task
  end
end
