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

  test "handle_tools_list returns all 11 tools" do
    response = @server.send(:handle, { "id" => 2, "method" => "tools/list" })
    tools = response[:result][:tools]
    assert_equal 11, tools.size
    tool_names = tools.map { |t| t[:name] }
    assert_includes tool_names, "create_task"
    assert_includes tool_names, "update_task_status"
    assert_includes tool_names, "list_my_tasks"
    assert_includes tool_names, "list_available_roles"
    assert_includes tool_names, "hire_role"
    assert_includes tool_names, "list_hirable_roles"
    assert_includes tool_names, "add_message"
    assert_includes tool_names, "get_task_details"
    assert_includes tool_names, "get_goal_details"
    assert_includes tool_names, "create_goal"
    assert_includes tool_names, "update_goal"
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
end
