require "test_helper"

class SubAgents::CreateTaskTest < ActiveSupport::TestCase
  setup do
    @role = roles(:cto)
    @role_run = role_runs(:running_run)
    @sub_agent = SubAgents::CreateTask.new(
      role: @role,
      arguments: {
        "intent" => "We need OAuth support for Google logins",
        "parent_task_id" => tasks(:design_homepage).id
      },
      parent_role_run: @role_run
    )
  end

  test "tool_definition exposes an MCP-compatible schema keyed on intent" do
    defn = SubAgents::CreateTask.tool_definition
    assert_equal "create_task", defn[:name]
    assert_includes defn[:inputSchema][:required], "intent"
    assert defn[:inputSchema][:properties].key?(:parent_task_id)
  end

  test "tool_scope routes the subprocess MCP server to the create-task tool set" do
    assert_equal :sub_agent_create_task, SubAgents::CreateTask.tool_scope
  end

  test "system_prompt is scoped to this one role and narrows the specialist's job" do
    prompt = @sub_agent.system_prompt
    assert_includes prompt, @role.title
    assert_includes prompt, @role.project.name
    assert_includes prompt, "ONE well-scoped task"
    assert_includes prompt, "list_available_roles"
    assert_includes prompt, "create_task"
  end

  test "user_message serializes intent and optional context fields" do
    message = @sub_agent.user_message
    assert_includes message, "OAuth support"
    assert_includes message, "Parent task id: #{tasks(:design_homepage).id}"
  end

  test "build_input_summary is short and searchable" do
    summary = @sub_agent.build_input_summary
    assert_includes summary, "OAuth"
    assert summary.length < 300
  end
end
