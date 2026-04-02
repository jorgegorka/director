require "test_helper"

class Tools::ListMyGoalsTest < ActiveSupport::TestCase
  setup do
    @cto = roles(:cto)
    @ceo = roles(:ceo)
    @developer = roles(:developer)
  end

  test "returns goals assigned to role" do
    tool = Tools::ListMyGoals.new(@cto)
    result = tool.call({})

    assert_equal 1, result[:count]
    assert_equal goals(:acme_objective_one).id, result[:goals].first[:id]
    assert_equal "Launch MVP by Q2", result[:goals].first[:title]
  end

  test "returns empty when role has no goals" do
    tool = Tools::ListMyGoals.new(@developer)
    result = tool.call({})

    assert_equal 0, result[:count]
    assert_empty result[:goals]
  end

  test "does not return goals from other companies" do
    tool = Tools::ListMyGoals.new(@ceo)
    result = tool.call({})

    titles = result[:goals].map { |g| g[:title] }
    assert_not_includes titles, "Dominate widget market"
  end

  test "includes expected fields" do
    tool = Tools::ListMyGoals.new(@cto)
    goal = tool.call({})[:goals].first

    assert_includes goal.keys, :id
    assert_includes goal.keys, :title
    assert_includes goal.keys, :description
    assert_includes goal.keys, :completion_percentage
    assert_includes goal.keys, :parent_id
  end
end
