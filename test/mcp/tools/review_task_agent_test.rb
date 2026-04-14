require "test_helper"

class Tools::ReviewTaskAgentTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @role = roles(:cto)
    @task = tasks(:fix_login_bug)
    @task.update_columns(status: Task.statuses[:pending_review])

    @root = Task.create!(
      title: "Root mission",
      project: @task.project,
      creator: roles(:ceo),
      assignee: @role,
      status: :in_progress
    )
    @task.update_columns(parent_task_id: @root.id)

    @role_run = role_runs(:completed_run)
    @role_run.update_columns(role_id: @role.id, status: RoleRun.statuses[:running])
  end

  test "call returns queued payload and enqueues a SubAgentJob for ReviewTask" do
    tool = Tools::ReviewTaskAgent.new(@role)

    result = nil
    assert_enqueued_with(job: SubAgentJob) do
      result = tool.call({ "task_id" => @task.id.to_s })
    end

    assert_equal "queued", result[:status]
    assert_equal "review_task", result[:sub_agent]
    assert result[:sub_agent_invocation_id].is_a?(Integer)
    assert result[:message].include?("background")

    invocation = SubAgentInvocation.find(result[:sub_agent_invocation_id])
    assert invocation.queued?
    assert_equal "review_task", invocation.sub_agent_name
  end
end
