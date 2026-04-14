require "test_helper"

class Tools::ListSubAgentInvocationsTest < ActiveSupport::TestCase
  setup do
    @role = roles(:cto)
    @role_run = role_runs(:completed_run)
    @role_run.update_columns(role_id: @role.id, status: RoleRun.statuses[:running])
    @tool = Tools::ListSubAgentInvocations.new(@role)
  end

  test "returns recent invocations for the current run, newest first" do
    old = SubAgentInvocation.enqueue!(role_run: @role_run, sub_agent_name: "create_task", input_summary: "one")
    old.update_columns(created_at: 2.minutes.ago)
    fresh = SubAgentInvocation.enqueue!(role_run: @role_run, sub_agent_name: "review_task", input_summary: "two")

    result = @tool.call({})

    assert_equal 2, result[:count]
    ids = result[:invocations].map { |i| i[:id] }
    assert_equal [ fresh.id, old.id ], ids
  end

  test "respects the limit argument and caps at MAX_LIMIT" do
    3.times { |i| SubAgentInvocation.enqueue!(role_run: @role_run, sub_agent_name: "create_task", input_summary: "n=#{i}") }

    limited = @tool.call({ "limit" => 2 })
    assert_equal 2, limited[:count]

    over_cap = @tool.call({ "limit" => 99 })
    assert_equal 3, over_cap[:count]
  end

  test "returns empty list when the role has no runs at all" do
    lonely_role = roles(:ceo)
    lonely_role.role_runs.destroy_all
    tool = Tools::ListSubAgentInvocations.new(lonely_role)

    result = tool.call({})

    assert_equal 0, result[:count]
    assert_equal [], result[:invocations]
  end

  test "does not surface invocations from other runs of the same role" do
    other_run = RoleRun.create!(role: @role, project: @role.project, status: :completed, trigger_type: "task_assigned")
    other_run.update_columns(created_at: 10.minutes.ago)
    SubAgentInvocation.enqueue!(role_run: other_run, sub_agent_name: "hire_role", input_summary: "foreign")

    current = SubAgentInvocation.enqueue!(role_run: @role_run, sub_agent_name: "create_task", input_summary: "mine")

    result = @tool.call({})

    assert_equal 1, result[:count]
    assert_equal current.id, result[:invocations].first[:id]
  end
end
