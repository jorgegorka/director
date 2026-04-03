require "test_helper"

class Dashboard::ApprovalQueueTest < ActiveSupport::TestCase
  setup do
    @company = companies(:acme)
    @queue = Dashboard::ApprovalQueue.new(@company)
  end

  test "gate_blocked_roles returns roles with pending_approval status" do
    roles = @queue.gate_blocked_roles
    assert roles.any?
    roles.each { |r| assert r.pending_approval? }
  end

  test "gate_blocked_roles scoped to company" do
    @queue.gate_blocked_roles.each do |role|
      assert_equal @company.id, role.company_id
    end
  end

  test "pending_hires returns actionable pending hires" do
    hires = @queue.pending_hires
    assert hires.any?
    hires.each { |h| assert h.pending? }
  end

  test "pending_hires scoped to company" do
    @queue.pending_hires.each do |hire|
      assert_equal @company.id, hire.company_id
    end
  end

  test "tasks_pending_review returns tasks with pending_review status" do
    tasks = @queue.tasks_pending_review
    assert tasks.any?
    tasks.each { |t| assert t.pending_review? }
  end

  test "tasks_pending_review scoped to company" do
    @queue.tasks_pending_review.each do |task|
      assert_equal @company.id, task.company_id
    end
  end

  test "total_count aggregates all approval types" do
    expected = @queue.gate_blocked_roles.size + @queue.pending_hires.size + @queue.tasks_pending_review.size
    assert_equal expected, @queue.total_count
  end

  test "any? returns true when approvals exist" do
    assert @queue.any?
  end

  test "other company not included" do
    widgets_queue = Dashboard::ApprovalQueue.new(companies(:widgets))
    assert_equal 0, widgets_queue.total_count
    assert_not widgets_queue.any?
  end
end
