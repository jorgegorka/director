class SubAgentJob < ApplicationJob
  queue_as :execution

  # Sub-agent runs are expensive and side-effectful (they spawn a claude CLI
  # subprocess and often mutate DB state). Do not retry automatically -- a
  # failed invocation is recorded on SubAgentInvocation for the orchestrator
  # to observe and retry deliberately.
  discard_on ActiveJob::DeserializationError

  def perform(invocation_id, sub_agent_class_name, role_id, arguments, parent_role_run_id)
    invocation = SubAgentInvocation.find_by(id: invocation_id)
    return unless invocation
    return if invocation.terminal?

    sub_agent_class = sub_agent_class_name.constantize
    role = Role.find(role_id)
    parent_role_run = RoleRun.find(parent_role_run_id)

    sub_agent = sub_agent_class.new(
      role: role,
      arguments: arguments,
      parent_role_run: parent_role_run
    )

    result = SubAgents::Runner.new.run(sub_agent, invocation: invocation)

    if sub_agent_class == SubAgents::ReviewTask && result.is_a?(Hash) && result[:status] == "ok"
      role.project.tasks.find_by(id: arguments["task_id"])
        &.chain_auto_summary_later!(parent_role_run: parent_role_run)
    end
  rescue StandardError => e
    if invocation && !invocation.terminal?
      invocation.fail!(error_message: e.message, cost_cents: 0, duration_ms: nil, iterations: 0)
    end
    raise
  end
end
