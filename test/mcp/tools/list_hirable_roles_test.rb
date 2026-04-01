require "test_helper"

class Tools::ListHirableRolesTest < ActiveSupport::TestCase
  test "CMO sees hirable roles from marketing template" do
    tool = Tools::ListHirableRoles.new(roles(:cmo))
    result = tool.call({})

    titles = result[:hirable_roles].map { |r| r[:title] }
    assert result[:count] > 0
    assert_includes titles, "Marketing Planner"
  end

  test "CEO returns empty hirable roles (no department template)" do
    tool = Tools::ListHirableRoles.new(roles(:ceo))
    result = tool.call({})

    assert_equal 0, result[:count]
    assert_empty result[:hirable_roles]
  end

  test "includes auto_hire_enabled status" do
    tool = Tools::ListHirableRoles.new(roles(:cmo))
    result = tool.call({})

    assert_equal false, result[:auto_hire_enabled]
  end

  test "each hirable role has title, description, and job_spec" do
    tool = Tools::ListHirableRoles.new(roles(:cmo))
    result = tool.call({})

    assert result[:hirable_roles].size > 0
    result[:hirable_roles].each do |r|
      assert r[:title].present?, "Hirable role should have title"
      assert r[:description].present?, "Hirable role should have description"
      assert r[:job_spec].present?, "Hirable role should have job_spec"
    end
  end
end
