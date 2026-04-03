class Tasks::ApprovalsController < ApplicationController
  include AgentApiAuthenticatable
  before_action :set_task

  def update
    unless @task.pending_review?
      return respond_error(@task, "Task is not pending review.")
    end

    @task.update!(status: :completed, reviewed_by: current_actor_role, reviewed_at: Time.current)

    @task.record_audit_event!(
      actor: current_actor,
      action: "approved",
      metadata: { reviewed_by: current_actor_role&.title || current_actor.try(:email_address) }
    )

    respond_success(@task, "Task approved and marked as completed.")
  end

  private

  def set_task
    @task = Current.company.tasks.find(params[:task_id])
  end

  def current_actor_role
    current_actor.is_a?(Role) ? current_actor : nil
  end
end
