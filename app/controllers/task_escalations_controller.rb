class TaskEscalationsController < ApplicationController
  include AgentApiAuthenticatable
  before_action :set_task

  def create
    manager_role = find_manager_role

    unless manager_role
      return respond_error(@task, "Cannot escalate -- no manager role found.")
    end

    old_assignee = @task.assignee
    @task.update!(assignee: manager_role)

    @task.record_audit_event!(
      actor: current_actor,
      action: "escalated",
      metadata: {
        from_role_id: old_assignee&.id,
        from_role_title: old_assignee&.title,
        to_role_id: manager_role.id,
        to_role_title: manager_role.title,
        reason: escalation_params[:reason].presence
      }
    )

    respond_success(@task, "Task escalated to #{manager_role.title}.")
  end

  private

  def escalation_params
    params.permit(:reason)
  end

  def find_manager_role
    @task.assignee&.manager_role
  end
end
