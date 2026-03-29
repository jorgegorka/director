require "test_helper"
require "webmock/minitest"

class HttpAdapterTest < ActiveSupport::TestCase
  AGENT_URL = "https://api.example.com/agent"

  setup do
    @role = roles(:developer)
    @context = {
      run_id: 1,
      trigger_type: "task_assigned",
      task_id: 42,
      task_title: "Fix login bug",
      task_description: "Users cannot log in"
    }

    HttpAdapter.define_singleton_method(:backoff_sleep) { |_n| nil }
  end

  teardown do
    HttpAdapter.singleton_class.remove_method(:backoff_sleep)
  end

  test "successful delivery returns result hash" do
    stub_request(:post, AGENT_URL)
      .to_return(status: 200, body: '{"status":"received"}', headers: { "Content-Type" => "application/json" })

    result = HttpAdapter.execute(@role, @context)

    assert_equal 0, result[:exit_code]
    assert_equal 200, result[:response_code]
    assert result.key?(:response_body)
  end

  test "payload includes role and task context" do
    stub_request(:post, AGENT_URL).to_return(status: 200, body: '{"ok":true}')

    HttpAdapter.execute(@role, @context)

    assert_requested(:post, AGENT_URL) do |req|
      body = JSON.parse(req.body)
      body["role_id"] == @role.id &&
        body["role_title"] == @role.title &&
        body["run_id"] == @context[:run_id] &&
        body["trigger_type"] == @context[:trigger_type] &&
        body["task"].present? &&
        body["task"]["id"] == @context[:task_id] &&
        body["task"]["title"] == @context[:task_title] &&
        body["task"]["description"] == @context[:task_description] &&
        body["delivered_at"].present?
    end
  end

  test "payload omits task when no task_id in context" do
    stub_request(:post, AGENT_URL).to_return(status: 200, body: "{}")

    context_without_task = @context.except(:task_id, :task_title, :task_description)
    HttpAdapter.execute(@role, context_without_task)

    assert_requested(:post, AGENT_URL) do |req|
      body = JSON.parse(req.body)
      body["task"].nil?
    end
  end

  test "4xx response raises PermanentError immediately without retry" do
    stub_request(:post, AGENT_URL).to_return(status: 404, body: "not found")

    assert_raises(HttpAdapter::PermanentError) do
      HttpAdapter.execute(@role, @context)
    end

    assert_requested(:post, AGENT_URL, times: 1)
  end

  test "401 response raises PermanentError" do
    stub_request(:post, AGENT_URL).to_return(status: 401, body: "Unauthorized")

    error = assert_raises(HttpAdapter::PermanentError) do
      HttpAdapter.execute(@role, @context)
    end

    assert_match(/401/, error.message)
  end

  test "5xx response retries and eventually raises TransientError" do
    stub_request(:post, AGENT_URL).to_return(status: 500, body: "server error")

    assert_raises(HttpAdapter::TransientError) do
      HttpAdapter.execute(@role, @context)
    end

    assert_requested(:post, AGENT_URL, times: HttpAdapter::MAX_RETRIES)
  end

  test "5xx then 2xx succeeds on retry" do
    stub_request(:post, AGENT_URL)
      .to_return(status: 500, body: "error").then
      .to_return(status: 200, body: '{"ok":true}')

    result = HttpAdapter.execute(@role, @context)

    assert_equal 0, result[:exit_code]
    assert_requested(:post, AGENT_URL, times: 2)
  end

  test "connection refused raises TransientError" do
    stub_request(:post, AGENT_URL).to_raise(Errno::ECONNREFUSED)

    assert_raises(HttpAdapter::TransientError) do
      HttpAdapter.execute(@role, @context)
    end
  end

  test "read timeout raises TransientError after retries" do
    stub_request(:post, AGENT_URL).to_timeout

    assert_raises(HttpAdapter::TransientError) do
      HttpAdapter.execute(@role, @context)
    end

    assert_requested(:post, AGENT_URL, times: HttpAdapter::MAX_RETRIES)
  end

  test "no URL configured raises PermanentError" do
    @role.adapter_config = {}

    error = assert_raises(HttpAdapter::PermanentError) do
      HttpAdapter.execute(@role, @context)
    end

    assert_match(/no url/i, error.message)
  end

  test "auth_token adds Authorization header" do
    @role.adapter_config["auth_token"] = "secret123"
    stub_request(:post, AGENT_URL)
      .with(headers: { "Authorization" => "Bearer secret123" })
      .to_return(status: 200, body: "{}")

    HttpAdapter.execute(@role, @context)

    assert_requested(:post, AGENT_URL, headers: { "Authorization" => "Bearer secret123" })
  end

  test "custom headers are merged" do
    @role.adapter_config["headers"] = { "X-Custom" => "value" }
    stub_request(:post, AGENT_URL)
      .with(headers: { "Content-Type" => "application/json", "X-Custom" => "value" })
      .to_return(status: 200, body: "{}")

    HttpAdapter.execute(@role, @context)

    assert_requested(:post, AGENT_URL, headers: { "Content-Type" => "application/json", "X-Custom" => "value" })
  end

  test "payload includes skills when present in context" do
    stub_request(:post, AGENT_URL).to_return(status: 200, body: '{"ok":true}')

    @context[:skills] = [
      { key: "code_review", name: "Code Review", description: "Review code", category: "technical", markdown: "# Code Review" }
    ]

    HttpAdapter.execute(@role, @context)

    assert_requested(:post, AGENT_URL) do |req|
      body = JSON.parse(req.body)
      body["skills"].is_a?(Array) &&
        body["skills"].length == 1 &&
        body["skills"][0]["key"] == "code_review"
    end
  end

  test "payload omits skills when none present" do
    stub_request(:post, AGENT_URL).to_return(status: 200, body: '{"ok":true}')

    @context[:skills] = []

    HttpAdapter.execute(@role, @context)

    assert_requested(:post, AGENT_URL) do |req|
      body = JSON.parse(req.body)
      !body.key?("skills")
    end
  end

  test "display_name, description, config_schema unchanged" do
    assert_equal "HTTP API", HttpAdapter.display_name
    assert_equal "Connect to a cloud-hosted agent via HTTP POST requests", HttpAdapter.description
    assert_equal %w[url], HttpAdapter.config_schema[:required]
    assert_includes HttpAdapter.config_schema[:optional], "auth_token"
  end
end
