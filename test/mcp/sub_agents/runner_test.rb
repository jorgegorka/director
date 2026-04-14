require "test_helper"

class SubAgents::RunnerTest < ActiveSupport::TestCase
  # We test the Runner by stubbing Open3.capture3 so no claude CLI is
  # actually spawned -- we feed it canned stream-json output and assert on
  # how it's parsed, how the SubAgentInvocation record evolves, and how cost
  # rolls up into the parent RoleRun.

  class StubSubAgent < SubAgents::Base
    def self.sub_agent_name = "stub"
    def self.tool_scope = :sub_agent_create_task
    def self.tool_definition
      { name: "stub", description: "stub", inputSchema: { type: "object" } }
    end
    def system_prompt = "you are a stub"
    def user_message  = "do the thing"
  end

  setup do
    @role_run = role_runs(:completed_run)
    @role_run.update_column(:cost_cents, 100)
    @role = @role_run.role
    @sub_agent = StubSubAgent.new(role: @role, arguments: {}, parent_role_run: @role_run)
  end

  def stream_json(events)
    events.map(&:to_json).join("\n")
  end

  # Duck-type Process::Status so the Runner's `capture` callers can ask
  # `.success?` and `.exitstatus` without a real child process.
  FakeStatus = Struct.new(:exitstatus) do
    def success? = exitstatus.zero?
  end

  def with_stubbed_runner(stdout, exitstatus: 0)
    runner = SubAgents::Runner.new
    status = FakeStatus.new(exitstatus)
    runner.define_singleton_method(:capture) { |**_| [ stdout, status ] }
    yield runner
  end

  test "happy path: parses stream-json, records cost, rolls up into parent RoleRun" do
    stdout = stream_json([
      { type: "assistant", message: { content: [ { type: "text", text: "Task created successfully." } ] } },
      { type: "result", session_id: "sess_sub_1", total_cost_usd: 0.012, subtype: "success" }
    ])

    with_stubbed_runner(stdout) do |runner|
      result = runner.run(@sub_agent)
      assert_equal "ok", result[:status]
      assert_equal 1, result[:cost_cents] # 0.012 USD -> round = 1 cent
      assert_equal "sess_sub_1", result[:session_id]
      assert_match(/Task created successfully/, result[:summary])
    end

    invocation = SubAgentInvocation.order(:id).last
    assert invocation.completed?
    assert_equal "stub", invocation.sub_agent_name
    assert_equal 1, invocation.cost_cents
    # Parent run baseline 100 + 1 cent sub-agent cost.
    assert_equal 101, @role_run.reload.cost_cents
  end

  test "claude exits with error_message -- invocation marked failed, cost still rolled up" do
    stdout = stream_json([
      { type: "result", subtype: "error", is_error: true, result: "agent reached max turns", total_cost_usd: 0.05, session_id: "sess_x" }
    ])

    with_stubbed_runner(stdout, exitstatus: 0) do |runner|
      result = runner.run(@sub_agent)
      assert_equal "error", result[:status]
      assert_match(/max turns/, result[:error])
      assert_equal 5, result[:cost_cents]
    end

    invocation = SubAgentInvocation.order(:id).last
    assert invocation.failed?
    assert_match(/max turns/, invocation.error_message)
    assert_equal 105, @role_run.reload.cost_cents
  end

  test "accepts pre-created queued invocation: flips to running, then completed" do
    stdout = stream_json([
      { type: "assistant", message: { content: [ { type: "text", text: "done" } ] } },
      { type: "result", session_id: "sess_kw", total_cost_usd: 0.004, subtype: "success" }
    ])

    invocation = SubAgentInvocation.enqueue!(
      role_run: @role_run,
      sub_agent_name: "stub",
      input_summary: "kwarg path"
    )
    assert invocation.queued?

    with_stubbed_runner(stdout) do |runner|
      runner.run(@sub_agent, invocation: invocation)
    end

    assert invocation.reload.completed?
    # No extra invocation row was created -- the pre-existing one was reused.
    assert_equal 1, SubAgentInvocation.where(sub_agent_name: "stub").count
  end

  test "no result event -- ClaudeLocalAdapter.parse_result raises and Runner records the failure" do
    stdout = stream_json([
      { type: "assistant", message: { content: [ { type: "text", text: "hi" } ] } }
      # no terminal `result` event
    ])

    with_stubbed_runner(stdout) do |runner|
      result = runner.run(@sub_agent)
      assert_equal "error", result[:status]
      assert_match(/without producing a result/i, result[:error])
    end

    invocation = SubAgentInvocation.order(:id).last
    assert invocation.failed?
  end
end
