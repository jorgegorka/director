class DirectorServer
  PROTOCOL_VERSION = "2024-11-05"

  attr_reader :role

  def initialize(role)
    @role = role
    @tools = DirectorServer.tool_classes.map { |klass| klass.new(role) }
  end

  def run
    $stdin.each_line do |line|
      request = JSON.parse(line.strip)
      response = handle(request)
      $stdout.puts(response.to_json)
      $stdout.flush
    rescue JSON::ParserError
      $stdout.puts(error_response(nil, -32700, "Parse error").to_json)
      $stdout.flush
    end
  end

  private

  def handle(request)
    id = request["id"]
    method = request["method"]

    case method
    when "initialize"
      handle_initialize(id)
    when "notifications/initialized"
      nil # No response needed for notifications
    when "tools/list"
      handle_tools_list(id)
    when "tools/call"
      handle_tools_call(id, request["params"])
    else
      error_response(id, -32601, "Method not found: #{method}")
    end
  end

  def handle_initialize(id)
    {
      jsonrpc: "2.0",
      id: id,
      result: {
        protocolVersion: PROTOCOL_VERSION,
        capabilities: { tools: {} },
        serverInfo: { name: "director", version: "1.0.0" }
      }
    }
  end

  def handle_tools_list(id)
    {
      jsonrpc: "2.0",
      id: id,
      result: {
        tools: @tools.map(&:definition)
      }
    }
  end

  def handle_tools_call(id, params)
    tool_name = params&.dig("name")
    arguments = params&.dig("arguments") || {}

    tool = @tools.find { |t| t.name == tool_name }
    return error_response(id, -32602, "Unknown tool: #{tool_name}") unless tool

    result = tool.call(arguments)

    {
      jsonrpc: "2.0",
      id: id,
      result: {
        content: [ { type: "text", text: result.to_json } ]
      }
    }
  rescue ActiveRecord::RecordInvalid => e
    tool_error_response(id, e.message)
  rescue ActiveRecord::RecordNotFound => e
    tool_error_response(id, e.message)
  rescue ArgumentError => e
    tool_error_response(id, e.message)
  end

  def error_response(id, code, message)
    { jsonrpc: "2.0", id: id, error: { code: code, message: message } }
  end

  def tool_error_response(id, message)
    {
      jsonrpc: "2.0",
      id: id,
      result: {
        content: [ { type: "text", text: message } ],
        isError: true
      }
    }
  end

  def self.tool_classes
    [
      Tools::CreateTask,
      Tools::UpdateTaskStatus,
      Tools::ListMyTasks,
      Tools::ListAvailableRoles,
      Tools::HireRole,
      Tools::ListHirableRoles,
      Tools::AddMessage,
      Tools::GetTaskDetails,
      Tools::GetGoalDetails,
      Tools::CreateGoal,
      Tools::UpdateGoal,
      Tools::SearchDocuments,
      Tools::GetDocument
    ]
  end
end
