class Tasks::RejectionsController < ApplicationController
  include AgentApiAuthenticatable
  before_action :set_task

  def update
    unless @task.pending_review?
      return respond_error(@task, "Task is not pending review.")
    end

    @task.update!(status: :open)

    if rejection_params[:feedback].present?
      @task.messages.create!(
        author: current_actor,
        body: rejection_params[:feedback],
        message_type: :comment
      )
    end

    @task.record_audit_event!(
      actor: current_actor,
      action: "rejected",
      metadata: {
        feedback: rejection_params[:feedback].presence,
        reviewed_by: current_actor_role&.title || current_actor.try(:email_address)
      }
    )

    respond_success(@task, "Task rejected and returned to open.")
  end

  private

  def set_task
    @task = Current.company.tasks.find(params[:task_id])
  end

  def rejection_params
    params.permit(:feedback)
  end

  def current_actor_role
    current_actor.is_a?(Role) ? current_actor : nil
  end
end
