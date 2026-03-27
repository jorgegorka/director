class TaskEscalationsController < ApplicationController
  include AgentApiAuthenticatable
  before_action :set_task

  def create
    manager_agent = find_manager_agent

    unless manager_agent
      return respond_error(@task, "Cannot escalate -- no manager with an assigned agent found.")
    end

    old_assignee = @task.assignee
    @task.update!(assignee: manager_agent)

    @task.record_audit_event!(
      actor: current_actor,
      action: "escalated",
      metadata: {
        from_agent_id: old_assignee&.id,
        from_agent_name: old_assignee&.name,
        to_agent_id: manager_agent.id,
        to_agent_name: manager_agent.name,
        reason: escalation_params[:reason].presence
      }
    )

    respond_success(@task, "Task escalated to #{manager_agent.name}.")
  end

  private

  def escalation_params
    params.permit(:reason)
  end

  def find_manager_agent
    @task.assignee&.manager_agent
  end
end
