require "test_helper"

class Tools::UpdateGoalTest < ActiveSupport::TestCase
  setup do
    @ceo = roles(:ceo)
    @cto = roles(:cto)
    @developer = roles(:developer)
    @company = companies(:acme)
    @objective_one = goals(:acme_objective_one)  # assigned to cto
    @objective_two = goals(:acme_objective_two)  # unassigned
  end

  test "assigned role can update completion_percentage" do
    tool = Tools::UpdateGoal.new(@cto)
    result = tool.call({
      "goal_id" => @objective_one.id,
      "completion_percentage" => 75
    })

    assert_equal 75, result[:completion_percentage]
    assert_equal 75, @objective_one.reload.completion_percentage
  end

  test "assigned role can update title" do
    tool = Tools::UpdateGoal.new(@cto)
    result = tool.call({
      "goal_id" => @objective_one.id,
      "title" => "Updated title"
    })

    assert_equal "Updated title", result[:title]
  end

  test "ancestor role can update goal" do
    tool = Tools::UpdateGoal.new(@ceo)
    result = tool.call({
      "goal_id" => @objective_one.id,
      "completion_percentage" => 50
    })

    assert_equal 50, result[:completion_percentage]
  end

  test "any role can update unassigned goal" do
    tool = Tools::UpdateGoal.new(@developer)
    result = tool.call({
      "goal_id" => @objective_two.id,
      "description" => "Now with a description"
    })

    assert_equal "Now with a description", result[:description]
  end

  test "non-authorized role cannot update assigned goal" do
    tool = Tools::UpdateGoal.new(@developer)
    assert_raises(ArgumentError) do
      tool.call({
        "goal_id" => @objective_one.id,
        "completion_percentage" => 50
      })
    end
  end

  test "rejects completion_percentage over 100" do
    tool = Tools::UpdateGoal.new(@cto)
    assert_raises(ActiveRecord::RecordInvalid) do
      tool.call({
        "goal_id" => @objective_one.id,
        "completion_percentage" => 150
      })
    end
  end

  test "rejects negative completion_percentage" do
    tool = Tools::UpdateGoal.new(@cto)
    assert_raises(ActiveRecord::RecordInvalid) do
      tool.call({
        "goal_id" => @objective_one.id,
        "completion_percentage" => -10
      })
    end
  end

  test "can reassign goal to different role" do
    tool = Tools::UpdateGoal.new(@ceo)
    result = tool.call({
      "goal_id" => @objective_one.id,
      "role_id" => @developer.id
    })

    assert_equal @developer.id, result[:role_id]
  end

  test "partial update does not clear other fields" do
    tool = Tools::UpdateGoal.new(@cto)
    original_title = @objective_one.title

    tool.call({
      "goal_id" => @objective_one.id,
      "completion_percentage" => 60
    })

    @objective_one.reload
    assert_equal original_title, @objective_one.title
    assert_equal 60, @objective_one.completion_percentage
  end

  test "goal not found in other company raises error" do
    widgets_mission = goals(:widgets_mission)
    tool = Tools::UpdateGoal.new(@cto)
    assert_raises(ActiveRecord::RecordNotFound) do
      tool.call({
        "goal_id" => widgets_mission.id,
        "completion_percentage" => 50
      })
    end
  end
end
