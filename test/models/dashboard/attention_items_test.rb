require "test_helper"

class Dashboard::AttentionItemsTest < ActiveSupport::TestCase
  setup do
    @project = projects(:acme)
    @attention = Dashboard::AttentionItems.new(@project)
  end

  test "tasks_pending_review returns tasks in pending_review status" do
    assert @attention.tasks_pending_review.any?
    assert @attention.tasks_pending_review.all?(&:pending_review?)
  end

  test "tasks_pending_review eager loads assignee, creator, and parent_task" do
    task = @attention.tasks_pending_review.first
    assert task.association(:assignee).loaded?
    assert task.association(:creator).loaded?
    assert task.association(:parent_task).loaded?
  end

  test "gate_blocked_roles returns roles with pending_approval status" do
    assert @attention.gate_blocked_roles.any?
    assert @attention.gate_blocked_roles.all?(&:pending_approval?)
  end

  test "gate_blocked_roles eager loads approval_gates" do
    role = @attention.gate_blocked_roles.first
    assert role.association(:approval_gates).loaded?
  end

  test "pending_hires returns pending hires for the project" do
    assert @attention.pending_hires.any?
    assert @attention.pending_hires.all? { |h| h.status == "pending" }
    assert @attention.pending_hires.all? { |h| h.project_id == @project.id }
  end

  test "pending_hires eager loads role" do
    hire = @attention.pending_hires.first
    assert hire.association(:role).loaded?
  end

  test "blocked_tasks returns tasks with blocked status" do
    # Create a blocked task for testing
    task = @project.tasks.create!(
      title: "Blocked task",
      status: :blocked,
      creator: roles(:ceo)
    )
    attention = Dashboard::AttentionItems.new(@project)
    assert_includes attention.blocked_tasks, task
  end

  test "blocked_tasks eager loads assignee and parent_task" do
    @project.tasks.create!(
      title: "Blocked task",
      status: :blocked,
      creator: roles(:ceo),
      assignee: roles(:developer),
      parent_task: tasks(:design_homepage)
    )
    attention = Dashboard::AttentionItems.new(@project)
    task = attention.blocked_tasks.first
    assert task.association(:assignee).loaded?
    assert task.association(:parent_task).loaded?
  end

  test "total_count sums all attention items" do
    expected = @attention.tasks_pending_review.size +
      @attention.gate_blocked_roles.size +
      @attention.pending_hires.size +
      @attention.blocked_tasks.size
    assert_equal expected, @attention.total_count
  end

  test "any? returns true when attention items exist" do
    assert @attention.any?
  end

  test "any? returns false when no attention items exist" do
    attention = Dashboard::AttentionItems.new(projects(:widgets))
    assert_not attention.any?
  end

  test "scoped to project only" do
    widgets_attention = Dashboard::AttentionItems.new(projects(:widgets))
    assert_not_equal @attention.total_count, widgets_attention.total_count
  end
end
