require "test_helper"

class Tools::GetSubAgentInvocationTest < ActiveSupport::TestCase
  setup do
    @role = roles(:cto)
    @role_run = role_runs(:completed_run)
    @role_run.update_columns(role_id: @role.id)
    @tool = Tools::GetSubAgentInvocation.new(@role)
  end

  test "returns serialized status fields for a queued invocation" do
    invocation = SubAgentInvocation.enqueue!(
      role_run: @role_run,
      sub_agent_name: "create_task",
      input_summary: "delegate onboarding"
    )

    result = @tool.call({ "invocation_id" => invocation.id })

    assert_equal invocation.id, result[:id]
    assert_equal "create_task", result[:sub_agent]
    assert_equal "queued", result[:status]
    assert_equal "delegate onboarding", result[:input_summary]
    assert_nil result[:result_summary]
    assert_nil result[:error_message]
  end

  test "surfaces completion fields for a finished invocation" do
    invocation = SubAgentInvocation.start!(role_run: @role_run, sub_agent_name: "review_task")
    invocation.finish!(result_summary: "approved", cost_cents: 12, duration_ms: 3400, iterations: 2)

    result = @tool.call({ "invocation_id" => invocation.id })

    assert_equal "completed", result[:status]
    assert_equal "approved", result[:result_summary]
    assert_equal 12, result[:cost_cents]
    assert_equal 3400, result[:duration_ms]
  end

  test "raises RecordNotFound when invocation belongs to a different project" do
    other_project = projects(:widgets)
    other_category = other_project.role_categories.first || other_project.role_categories.create!(name: "ops", job_spec: "Run operations")
    other_role = other_project.roles.create!(title: "Other CEO", role_category: other_category, job_spec: "lead")
    other_run = RoleRun.create!(role: other_role, project: other_project, status: :running, trigger_type: "task_assigned")
    foreign = SubAgentInvocation.start!(role_run: other_run, sub_agent_name: "create_task")

    assert_raises(ActiveRecord::RecordNotFound) do
      @tool.call({ "invocation_id" => foreign.id })
    end
  end
end
