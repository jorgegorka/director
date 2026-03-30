require "test_helper"

class PendingHireTest < ActiveSupport::TestCase
  setup do
    @pending_hire = pending_hires(:pending_vp_hire)
    @user = users(:one)
  end

  test "valid pending hire" do
    assert @pending_hire.valid?
  end

  test "requires role" do
    @pending_hire.role = nil
    assert_not @pending_hire.valid?
  end

  test "requires company" do
    @pending_hire.company = nil
    assert_not @pending_hire.valid?
  end

  test "requires template_role_title" do
    @pending_hire.template_role_title = nil
    assert_not @pending_hire.valid?
  end

  test "requires budget_cents" do
    @pending_hire.budget_cents = nil
    assert_not @pending_hire.valid?
  end

  test "budget_cents must be positive" do
    @pending_hire.budget_cents = 0
    assert_not @pending_hire.valid?

    @pending_hire.budget_cents = -1
    assert_not @pending_hire.valid?
  end

  test "default status is pending" do
    hire = PendingHire.new(role: roles(:cto), company: companies(:acme), template_role_title: "QA", budget_cents: 10000)
    assert hire.pending?
  end

  test "approve! sets status and resolved fields" do
    @pending_hire.approve!(@user)
    assert @pending_hire.approved?
    assert_equal @user, @pending_hire.resolved_by
    assert_not_nil @pending_hire.resolved_at
  end

  test "reject! sets status and resolved fields" do
    @pending_hire.reject!(@user)
    assert @pending_hire.rejected?
    assert_equal @user, @pending_hire.resolved_by
    assert_not_nil @pending_hire.resolved_at
  end

  test "cannot approve already resolved hire" do
    @pending_hire.approve!(@user)
    assert_raises(ActiveRecord::RecordInvalid) { @pending_hire.approve!(@user) }
  end

  test "cannot reject already resolved hire" do
    @pending_hire.reject!(@user)
    assert_raises(ActiveRecord::RecordInvalid) { @pending_hire.reject!(@user) }
  end
end
