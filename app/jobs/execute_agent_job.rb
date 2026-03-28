class ExecuteAgentJob < ApplicationJob
  queue_as :execution

  # Do not retry execution jobs automatically -- failed runs should be
  # investigated or manually retried. The ensure block guarantees cleanup.
  discard_on ActiveJob::DeserializationError

  def perform(agent_run_id)
    agent_run = AgentRun.find_by(id: agent_run_id)
    return unless agent_run
    return if agent_run.terminal?

    agent = agent_run.agent
    agent_run.mark_running!
    agent.update!(status: :running)

    result = agent.adapter_class.execute(agent, build_context(agent_run))

    agent_run.mark_completed!(
      exit_code: result&.dig(:exit_code),
      cost_cents: result&.dig(:cost_cents),
      claude_session_id: result&.dig(:session_id)
    )
    agent.update!(status: :idle)
  rescue Exception => e # rubocop:disable Lint/RescueException
    if agent_run && !agent_run.terminal?
      agent_run.mark_failed!(error_message: e.message, exit_code: 1)
    end
    agent&.update!(status: :idle) if agent&.running?
  end

  private

  def build_context(agent_run)
    ctx = {
      run_id: agent_run.id,
      trigger_type: agent_run.trigger_type
    }

    if agent_run.task.present?
      ctx[:task_id] = agent_run.task_id
      ctx[:task_title] = agent_run.task.title
      ctx[:task_description] = agent_run.task.description
    end

    # Pass session ID for Claude conversation resumption (EXEC-03)
    session_id = agent_run.agent.latest_session_id
    ctx[:resume_session_id] = session_id if session_id.present?

    ctx
  end
end
