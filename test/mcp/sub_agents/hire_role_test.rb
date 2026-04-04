require "test_helper"

class SubAgents::HireRoleTest < ActiveSupport::TestCase
  setup do
    @role = roles(:cmo)
    @role_run = role_runs(:running_run)
    @sub_agent = SubAgents::HireRole.new(
      role: @role,
      arguments: { "intent" => "Need someone to draft weekly newsletters", "budget_ceiling_cents" => 15_000 },
      parent_role_run: @role_run
    )
  end

  test "tool_definition requires intent and optionally accepts a budget ceiling" do
    defn = SubAgents::HireRole.tool_definition
    assert_equal "hire_role", defn[:name]
    assert_includes defn[:inputSchema][:required], "intent"
    assert defn[:inputSchema][:properties].key?(:budget_ceiling_cents)
  end

  test "tool_scope routes to the hire-role tool set" do
    assert_equal :sub_agent_hire_role, SubAgents::HireRole.tool_scope
  end

  test "system_prompt references the hiring role's budget ceiling" do
    prompt = @sub_agent.system_prompt
    assert_includes prompt, "hiring specialist"
    # cmo has budget_cents: 50000 in fixtures
    assert_includes prompt, "50000 cents/month"
    assert_includes prompt, "hire_role exactly once"
  end

  test "user_message includes intent and budget ceiling" do
    message = @sub_agent.user_message
    assert_includes message, "newsletters"
    assert_includes message, "15000"
  end
end
