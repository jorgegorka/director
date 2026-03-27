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

  def set_task
    @task = Current.company.tasks.find_by(id: params[:id])
    respond_not_found unless @task
  end

  def escalation_params
    params.permit(:reason)
  end

  # Find the agent assigned to the parent role of the current assignee's role.
  # Walks up the hierarchy until finding a role with an assigned agent.
  # Returns nil if no assignee, no role, no parent, or no parent has an agent.
  def find_manager_agent
    return nil unless @task.assignee.present?

    current_role = @task.assignee.roles.for_current_company.first
    return nil unless current_role

    parent_role = current_role.parent
    while parent_role
      return parent_role.agent if parent_role.agent.present?

      parent_role = parent_role.parent
    end

    nil
  end
end
