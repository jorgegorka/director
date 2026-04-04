require "test_helper"

class Tools::UpdateGoalSummaryTest < ActiveSupport::TestCase
  setup do
    @ceo = roles(:ceo)
    @cto = roles(:cto)
    @developer = roles(:developer)
    @objective_one = goals(:acme_objective_one) # assigned to cto
    @objective_two = goals(:acme_objective_two) # unassigned
  end

  test "assigned role can write the summary" do
    tool = Tools::UpdateGoalSummary.new(@cto)
    result = tool.call({
      "goal_id" => @objective_one.id,
      "summary" => "Delivered the MVP launch across the three core flows via Task #design_homepage and Task #fix_login_bug."
    })

    assert_equal "ok", result[:status]
    assert_match(/Delivered the MVP/, @objective_one.reload.summary)
  end

  test "ancestor role can write the summary" do
    tool = Tools::UpdateGoalSummary.new(@ceo)
    tool.call({ "goal_id" => @objective_one.id, "summary" => "Top-down approval." })

    assert_equal "Top-down approval.", @objective_one.reload.summary
  end

  test "unrelated role cannot write the summary of an assigned goal" do
    tool = Tools::UpdateGoalSummary.new(@developer)
    assert_raises(ArgumentError) do
      tool.call({ "goal_id" => @objective_one.id, "summary" => "Hostile takeover." })
    end
  end

  test "any role can write the summary of an unassigned goal" do
    tool = Tools::UpdateGoalSummary.new(@developer)
    tool.call({ "goal_id" => @objective_two.id, "summary" => "Unclaimed outcome." })

    assert_equal "Unclaimed outcome.", @objective_two.reload.summary
  end

  test "blank summary is rejected" do
    tool = Tools::UpdateGoalSummary.new(@cto)
    assert_raises(ArgumentError) do
      tool.call({ "goal_id" => @objective_one.id, "summary" => "   " })
    end
  end

  test "summary over max length is rejected" do
    tool = Tools::UpdateGoalSummary.new(@cto)
    assert_raises(ArgumentError) do
      tool.call({
        "goal_id" => @objective_one.id,
        "summary" => "x" * (Tools::UpdateGoalSummary::MAX_SUMMARY_LENGTH + 1)
      })
    end
  end

  test "cannot update a goal from another account" do
    widgets_mission = goals(:widgets_mission)
    tool = Tools::UpdateGoalSummary.new(@cto)
    assert_raises(ActiveRecord::RecordNotFound) do
      tool.call({ "goal_id" => widgets_mission.id, "summary" => "Not mine." })
    end
  end
end
