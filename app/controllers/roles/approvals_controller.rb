class Roles::ApprovalsController < ApplicationController
  include ActionView::RecordIdentifier
  include Roles::OrgChartStreamable
  include Triggerable

  # approve
  def create
    unless @role.pending_approval?
      redirect_to @role, alert: "#{@role.title} is not pending approval."
      return
    end

    feedback = feedback_param
    pending_hire = @role.pending_hires.actionable.last
    if pending_hire
      @role.execute_hire!(pending_hire)
      pending_hire.approve!(Current.user, feedback: feedback)
    end

    @role.update!(
      status: :idle,
      pause_reason: nil,
      paused_at: nil
    )
    @role.record_audit_event!(actor: Current.user, action: "gate_approval", metadata: { feedback: feedback })

    if feedback.present?
      trigger_role_wake(
        role: @role,
        trigger_type: :manual,
        trigger_source: "Roles::ApprovalsController#create",
        context: { human_feedback: feedback }
      )
    end

    respond_to_with_approval_stream("#{@role.title} has been approved and resumed.")
  end

  # reject
  def destroy
    unless @role.pending_approval?
      redirect_to @role, alert: "#{@role.title} is not pending approval."
      return
    end

    feedback = feedback_param
    pending_hire = @role.pending_hires.actionable.last
    pending_hire&.reject!(Current.user, feedback: feedback)

    pause_reason = feedback ? "Approval rejected: #{feedback}" : "Approval rejected"
    @role.update!(
      status: :paused,
      pause_reason: pause_reason,
      paused_at: Time.current
    )
    @role.record_audit_event!(actor: Current.user, action: "gate_rejection", metadata: { reason: pause_reason, feedback: feedback })

    respond_to_with_approval_stream("#{@role.title} approval has been rejected.")
  end

  private

  def feedback_param
    params[:feedback].to_s.strip.presence
  end

  def respond_to_with_approval_stream(notice)
    respond_to do |format|
      format.turbo_stream do
        Dashboard::AttentionItems.new(Current.project).broadcast_to(Current.project.id)
        render turbo_stream: turbo_stream.remove(dom_id(@role, :approval))
      end
      format.html { redirect_to @role, notice: notice }
    end
  end
end
