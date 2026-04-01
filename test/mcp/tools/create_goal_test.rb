require "test_helper"

class Tools::CreateGoalTest < ActiveSupport::TestCase
  setup do
    @ceo = roles(:ceo)
    @cto = roles(:cto)
    @company = companies(:acme)
    @mission = goals(:acme_mission)
  end

  test "creates goal with title only" do
    tool = Tools::CreateGoal.new(@ceo)
    result = tool.call({ "title" => "New initiative" })

    assert result[:id].present?
    assert_equal "New initiative", result[:title]
    assert_nil result[:parent_id]
    assert_nil result[:role_id]
    assert_equal 0, result[:position]
  end

  test "creates goal under parent" do
    tool = Tools::CreateGoal.new(@ceo)
    result = tool.call({
      "title" => "Sub-goal",
      "parent_goal_id" => @mission.id
    })

    goal = Goal.find(result[:id])
    assert_equal @mission, goal.parent
  end

  test "creates goal with role assignment" do
    tool = Tools::CreateGoal.new(@ceo)
    result = tool.call({
      "title" => "CTO objective",
      "role_id" => @cto.id
    })

    assert_equal @cto.id, result[:role_id]
  end

  test "creates goal with all fields" do
    tool = Tools::CreateGoal.new(@ceo)
    result = tool.call({
      "title" => "Full goal",
      "description" => "Detailed desc",
      "parent_goal_id" => @mission.id,
      "role_id" => @cto.id,
      "position" => 5
    })

    goal = Goal.find(result[:id])
    assert_equal "Full goal", goal.title
    assert_equal "Detailed desc", goal.description
    assert_equal @mission, goal.parent
    assert_equal @cto, goal.role
    assert_equal 5, goal.position
  end

  test "rejects duplicate title under same parent" do
    tool = Tools::CreateGoal.new(@ceo)
    assert_raises(ActiveRecord::RecordInvalid) do
      tool.call({
        "title" => "Launch MVP by Q2",
        "parent_goal_id" => @mission.id
      })
    end
  end

  test "rejects role from different company" do
    widgets_lead = roles(:widgets_lead)
    tool = Tools::CreateGoal.new(@ceo)
    assert_raises(ActiveRecord::RecordInvalid) do
      tool.call({
        "title" => "Cross-company goal",
        "role_id" => widgets_lead.id
      })
    end
  end

  test "rejects parent from different company" do
    widgets_mission = goals(:widgets_mission)
    tool = Tools::CreateGoal.new(@ceo)
    assert_raises(ActiveRecord::RecordInvalid) do
      tool.call({
        "title" => "Cross-company child",
        "parent_goal_id" => widgets_mission.id
      })
    end
  end
end
