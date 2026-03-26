require "test_helper"

class CompanyTest < ActiveSupport::TestCase
  test "valid with name" do
    company = Company.new(name: "Test Corp")
    assert company.valid?
  end

  test "invalid without name" do
    company = Company.new(name: nil)
    assert_not company.valid?
    assert_includes company.errors[:name], "can't be blank"
  end

  test "has many memberships" do
    company = companies(:acme)
    assert_equal 2, company.memberships.count
  end

  test "has many users through memberships" do
    company = companies(:acme)
    assert_includes company.users, users(:one)
    assert_includes company.users, users(:two)
  end

  test "destroying company destroys memberships" do
    company = companies(:acme)
    assert_difference("Membership.count", -2) do
      company.destroy
    end
  end
end
