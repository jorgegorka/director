class TaskDelegationsController < ApplicationController
  include AgentApiAuthenticatable
  before_action :set_task

  def create
    target_agent = Current.company.agents.find_by(id: delegation_params[:agent_id])

    unless target_agent
      return respond_error(@task, "Agent not found.")
    end

    unless valid_delegation_target?(target_agent)
      return respond_error(@task, "Cannot delegate to this agent -- they must be assigned to a subordinate role.")
    end

    old_assignee = @task.assignee
    @task.update!(assignee: target_agent)

    @task.record_audit_event!(
      actor: current_actor,
      action: "delegated",
      metadata: {
        from_agent_id: old_assignee&.id,
        from_agent_name: old_assignee&.name,
        to_agent_id: target_agent.id,
        to_agent_name: target_agent.name,
        reason: delegation_params[:reason].presence
      }
    )

    respond_success(@task, "Task delegated to #{target_agent.name}.")
  end

  private

  def delegation_params
    params.permit(:agent_id, :reason)
  end

  def valid_delegation_target?(target_agent)
    @task.assignee.present? && @task.assignee.subordinate_agents.exists?(target_agent.id)
  end
end
