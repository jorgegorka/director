require "test_helper"

class Dashboard::TaskBoardTest < ActiveSupport::TestCase
  setup do
    @project = projects(:acme)
    @task_board = Dashboard::TaskBoard.new(@project)
  end

  test "tasks_by_status includes all status keys" do
    assert_equal Task.statuses.keys.sort, @task_board.tasks_by_status.keys.sort
  end

  test "tasks_by_status groups tasks correctly" do
    @task_board.tasks_by_status.each do |status, tasks|
      tasks.each { |t| assert_equal status, t.status }
    end
  end

  test "all_tasks scoped to project" do
    @task_board.all_tasks.each do |task|
      assert_equal @project.id, task.project_id
    end
  end

  test "all_tasks ordered by priority desc then created_at desc" do
    tasks = @task_board.all_tasks.to_a
    tasks.each_cons(2) do |a, b|
      if a.priority == b.priority
        assert a.created_at >= b.created_at, "Expected tasks with same priority to be ordered by created_at desc"
      else
        assert Task.priorities[a.priority] >= Task.priorities[b.priority], "Expected tasks ordered by priority desc"
      end
    end
  end

  test "all_tasks eager loads assignee and creator" do
    task = @task_board.all_tasks.first
    assert task.association(:assignee).loaded?
    assert task.association(:creator).loaded?
  end

  test "scoped to project only" do
    widgets_board = Dashboard::TaskBoard.new(projects(:widgets))
    assert_not_equal @task_board.all_tasks.count, widgets_board.all_tasks.count
  end
end
