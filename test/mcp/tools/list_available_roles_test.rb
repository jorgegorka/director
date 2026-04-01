require "test_helper"

class Tools::ListAvailableRolesTest < ActiveSupport::TestCase
  test "CEO sees all subordinates" do
    tool = Tools::ListAvailableRoles.new(roles(:ceo))
    result = tool.call({})

    titles = result[:roles].map { |r| r[:title] }
    assert_includes titles, "CTO"
    assert_includes titles, "Senior Developer"
    assert result[:count] > 0
  end

  test "CTO sees subordinates and siblings" do
    tool = Tools::ListAvailableRoles.new(roles(:cto))
    result = tool.call({})

    titles = result[:roles].map { |r| r[:title] }
    # CTO's children
    assert_includes titles, "Senior Developer"
    assert_includes titles, "Script Runner"
    # CTO should not see itself
    refute_includes titles, "CTO"
  end

  test "roles include relationship type" do
    tool = Tools::ListAvailableRoles.new(roles(:ceo))
    result = tool.call({})

    cto_role = result[:roles].find { |r| r[:title] == "CTO" }
    assert_equal "subordinate", cto_role[:relationship]
  end
end
