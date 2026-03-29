class TaskDelegationsController < ApplicationController
  include AgentApiAuthenticatable
  before_action :set_task

  def create
    target_role = Current.company.roles.find_by(id: delegation_params[:role_id])

    unless target_role
      return respond_error(@task, "Role not found.")
    end

    unless valid_delegation_target?(target_role)
      return respond_error(@task, "Cannot delegate to this role -- they must be a subordinate role.")
    end

    old_assignee = @task.assignee
    @task.update!(assignee: target_role)

    @task.record_audit_event!(
      actor: current_actor,
      action: "delegated",
      metadata: {
        from_role_id: old_assignee&.id,
        from_role_title: old_assignee&.title,
        to_role_id: target_role.id,
        to_role_title: target_role.title,
        reason: delegation_params[:reason].presence
      }
    )

    respond_success(@task, "Task delegated to #{target_role.title}.")
  end

  private

  def delegation_params
    params.permit(:role_id, :reason)
  end

  def valid_delegation_target?(target_role)
    @task.assignee.present? && @task.assignee.subordinate_roles.exists?(target_role.id)
  end
end
