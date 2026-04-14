require "test_helper"

class DirectorServerTest < ActiveSupport::TestCase
  setup do
    @role = roles(:cto)
    @server = DirectorServer.new(@role)
  end

  test "handle_initialize returns protocol version and capabilities" do
    response = @server.send(:handle, { "id" => 1, "method" => "initialize" })
    assert_equal "2.0", response[:jsonrpc]
    assert_equal 1, response[:id]
    assert_equal "director", response[:result][:serverInfo][:name]
    assert_equal DirectorServer::PROTOCOL_VERSION, response[:result][:protocolVersion]
  end

  test "handle_tools_list returns all registered tools" do
    response = @server.send(:handle, { "id" => 2, "method" => "tools/list" })
    tools = response[:result][:tools]
    tool_names = tools.map { |t| t[:name] }

    # Agentic operations are exposed via sub-agent wrappers that share the
    # same tool names as the old direct tools -- plus review_task, which is
    # new as of the sub-agent split.
    assert_includes tool_names, "create_task"
    assert_includes tool_names, "review_task"
    assert_includes tool_names, "hire_role"
    assert_includes tool_names, "summarize_task"

    # Mechanical direct tools.
    assert_includes tool_names, "update_task_status"
    assert_includes tool_names, "list_my_tasks"
    assert_includes tool_names, "list_available_roles"
    assert_includes tool_names, "list_hirable_roles"
    assert_includes tool_names, "add_message"
    assert_includes tool_names, "get_task_details"
    assert_includes tool_names, "search_documents"
    assert_includes tool_names, "get_document"

    assert_includes tool_names, "get_sub_agent_invocation"
    assert_includes tool_names, "list_sub_agent_invocations"

    assert_equal 14, tools.size
  end

  test "sub-agent wrapper tools resolve the parent role_run and expose a valid MCP definition" do
    response = @server.send(:handle, { "id" => 6, "method" => "tools/list" })
    create_task = response[:result][:tools].find { |t| t[:name] == "create_task" }
    assert_equal "create_task", create_task[:name]
    # The sub-agent wrapper passes through the SubAgents::CreateTask schema,
    # which requires an `intent` field -- different from the old direct tool
    # which required `title`.
    assert_includes create_task[:inputSchema][:required], "intent"
  end

  test "sub_agent_create_task scope exposes only the reads + direct create_task, no wrappers" do
    scoped = DirectorServer.new(@role, tool_scope: :sub_agent_create_task)
    names = scoped.send(:handle, { "id" => 7, "method" => "tools/list" })
      .dig(:result, :tools).map { |t| t[:name] }

    assert_equal %w[get_task_details list_available_roles create_task].sort, names.sort

    # Inside the scope, `create_task` is the direct mutation tool (requires
    # title), not the sub-agent wrapper -- that's what prevents recursion.
    create_task = scoped.send(:handle, { "id" => 8, "method" => "tools/list" })
      .dig(:result, :tools).find { |t| t[:name] == "create_task" }
    assert_includes create_task[:inputSchema][:required], "title"
  end

  test "sub_agent_review_task scope exposes only get_task_details and submit_review_decision" do
    scoped = DirectorServer.new(@role, tool_scope: :sub_agent_review_task)
    names = scoped.send(:handle, { "id" => 9, "method" => "tools/list" })
      .dig(:result, :tools).map { |t| t[:name] }

    assert_equal %w[get_task_details submit_review_decision].sort, names.sort
  end

  test "sub_agent_hire_role scope exposes only list_hirable_roles and the direct hire_role" do
    scoped = DirectorServer.new(@role, tool_scope: :sub_agent_hire_role)
    names = scoped.send(:handle, { "id" => 10, "method" => "tools/list" })
      .dig(:result, :tools).map { |t| t[:name] }

    assert_equal %w[list_hirable_roles hire_role].sort, names.sort
  end

  test "sub_agent_summarize_task scope exposes only get_task_details and the direct update_task_summary" do
    scoped = DirectorServer.new(@role, tool_scope: :sub_agent_summarize_task)
    names = scoped.send(:handle, { "id" => 11, "method" => "tools/list" })
      .dig(:result, :tools).map { |t| t[:name] }

    assert_equal %w[get_task_details update_task_summary].sort, names.sort
  end

  test "unknown tool scope raises on server construction" do
    assert_raises(ArgumentError) do
      DirectorServer.new(@role, tool_scope: :bogus)
    end
  end

  test "handle_tools_call with unknown tool returns error" do
    response = @server.send(:handle, {
      "id" => 3,
      "method" => "tools/call",
      "params" => { "name" => "nonexistent", "arguments" => {} }
    })
    assert_equal(-32602, response[:error][:code])
  end

  test "handle unknown method returns error" do
    response = @server.send(:handle, { "id" => 4, "method" => "unknown/method" })
    assert_equal(-32601, response[:error][:code])
  end

  test "handle_tools_call routes to correct tool" do
    response = @server.send(:handle, {
      "id" => 5,
      "method" => "tools/call",
      "params" => {
        "name" => "list_my_tasks",
        "arguments" => {}
      }
    })
    result = JSON.parse(response[:result][:content][0][:text])
    assert result.key?("tasks")
    assert result.key?("count")
  end

  test "handle_tools_call returns loud error when a required argument is missing after sanitization" do
    task = tasks(:design_homepage)

    response = @server.send(:handle, {
      "id" => 20,
      "method" => "tools/call",
      "params" => {
        "name" => "add_message",
        "arguments" => { "task_id" => task.id, "content" => "# deliverable" }
      }
    })

    assert response[:result][:isError], "expected sanitization to surface an isError result"
    error_text = response[:result][:content][0][:text]
    assert_match(/missing required/i, error_text)
    assert_includes error_text, "message"
  end

  test "handle_tools_call silently drops unknown arguments when required keys are present" do
    task = tasks(:design_homepage)

    assert_difference -> { task.messages.count }, 1 do
      response = @server.send(:handle, {
        "id" => 21,
        "method" => "tools/call",
        "params" => {
          "name" => "add_message",
          "arguments" => {
            "task_id" => task.id,
            "message" => "hello from sanitization test",
            "random_extra" => "should be ignored"
          }
        }
      })
      refute response[:result][:isError], "unknown keys should be silently dropped, not raised"
      result = JSON.parse(response[:result][:content][0][:text])
      assert_equal task.id, result["task_id"]
    end
  end
end
