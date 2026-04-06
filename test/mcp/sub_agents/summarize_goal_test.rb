require "test_helper"

class SubAgents::SummarizeGoalTest < ActiveSupport::TestCase
  setup do
    @role = roles(:cto)
    @role_run = role_runs(:running_run)
    @goal = goals(:acme_objective_one)
    @sub_agent = SubAgents::SummarizeGoal.new(
      role: @role,
      arguments: { "goal_id" => @goal.id },
      parent_role_run: @role_run
    )
  end

  test "tool_definition exposes an MCP-compatible schema keyed on goal_id" do
    defn = SubAgents::SummarizeGoal.tool_definition
    assert_equal "summarize_goal", defn[:name]
    assert_includes defn[:inputSchema][:required], "goal_id"
    assert defn[:inputSchema][:properties].key?(:goal_id)
  end

  test "tool_scope routes the subprocess MCP server to the summarize-goal tool set" do
    assert_equal :sub_agent_summarize_goal, SubAgents::SummarizeGoal.tool_scope
  end

  test "system_prompt is scoped to this one role and narrows the specialist's job" do
    prompt = @sub_agent.system_prompt
    assert_includes prompt, @role.title
    assert_includes prompt, @role.company.name
    assert_includes prompt, "get_goal_details"
    assert_includes prompt, "update_goal_summary"
    assert_includes prompt, "markdown link"
  end

  test "user_message serializes the goal id" do
    assert_equal "Goal id: #{@goal.id}", @sub_agent.user_message
  end

  test "build_input_summary is short and searchable" do
    summary = @sub_agent.build_input_summary
    assert_includes summary, "goal_id=#{@goal.id}"
    assert summary.length < 100
  end

  test "max_turns is capped tight for this single-decision sub-agent" do
    assert_equal 6, @sub_agent.max_turns
  end
end
