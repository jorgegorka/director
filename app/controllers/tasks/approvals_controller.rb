class Tasks::ApprovalsController < ApplicationController
  include AgentApiAuthenticatable
  before_action :set_task
  before_action :require_pending_review

  def update
    @task.update!(status: :completed, reviewed_by: current_actor_role, reviewed_at: Time.current)

    @task.record_audit_event!(
      actor: current_actor,
      action: "approved",
      metadata: { reviewed_by: current_actor_role&.title || current_actor.try(:email_address) }
    )

    respond_success(@task, "Task approved and marked as completed.")
  end
end
