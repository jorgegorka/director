class TaskReviewsController < ApplicationController
  include AgentApiAuthenticatable
  before_action :set_task

  def approve
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

  def reject
    unless @task.pending_review?
      return respond_error(@task, "Task is not pending review.")
    end

    @task.update!(status: :open)

    if reject_params[:feedback].present?
      @task.messages.create!(
        author: current_actor,
        body: reject_params[:feedback],
        message_type: :comment
      )
    end

    @task.record_audit_event!(
      actor: current_actor,
      action: "rejected",
      metadata: {
        feedback: reject_params[:feedback].presence,
        reviewed_by: current_actor_role&.title || current_actor.try(:email_address)
      }
    )

    respond_success(@task, "Task rejected and returned to open.")
  end

  private

  def reject_params
    params.permit(:feedback)
  end

  def current_actor_role
    current_actor.is_a?(Role) ? current_actor : nil
  end
end
