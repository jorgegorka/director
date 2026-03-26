require "test_helper"

class MembershipTest < ActiveSupport::TestCase
  test "valid with company, user, and role" do
    membership = Membership.new(company: companies(:widgets), user: users(:two), role: :member)
    assert membership.valid?
  end

  test "invalid without company" do
    membership = Membership.new(user: users(:one), role: :member)
    assert_not membership.valid?
  end

  test "invalid without user" do
    membership = Membership.new(company: companies(:acme), role: :member)
    assert_not membership.valid?
  end

  test "enforces unique user per company" do
    # user :one already has membership in :acme via fixtures
    duplicate = Membership.new(company: companies(:acme), user: users(:one), role: :member)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user_id], "is already a member of this company"
  end

  test "same user can belong to multiple companies" do
    # user :one already belongs to acme and widgets via fixtures
    assert_equal 2, users(:one).memberships.count
  end

  test "role enum works" do
    assert memberships(:one_owns_acme).owner?
    assert memberships(:two_member_acme).member?
    assert memberships(:one_admin_widgets).admin?
  end

  test "default role is member" do
    membership = Membership.new
    assert_equal "member", membership.role
  end
end
