class Roles::ApprovalsController < ApplicationController
  include ActionView::RecordIdentifier
  include Roles::OrgChartStreamable

  # approve
  def create
    unless @role.pending_approval?
      redirect_to @role, alert: "#{@role.title} is not pending approval."
      return
    end

    pending_hire = @role.pending_hires.actionable.last
    if pending_hire
      @role.execute_hire!(pending_hire)
      pending_hire.approve!(Current.user)
    end

    @role.update!(
      status: :idle,
      pause_reason: nil,
      paused_at: nil
    )
    @role.record_audit_event!(actor: Current.user, action: "gate_approval")

    respond_to_with_approval_stream("#{@role.title} has been approved and resumed.")
  end

  # reject
  def destroy
    unless @role.pending_approval?
      redirect_to @role, alert: "#{@role.title} is not pending approval."
      return
    end

    pending_hire = @role.pending_hires.actionable.last
    pending_hire&.reject!(Current.user)

    @role.update!(
      status: :paused,
      pause_reason: "Approval rejected: #{params[:reason].presence || 'No reason given'}",
      paused_at: Time.current
    )
    @role.record_audit_event!(actor: Current.user, action: "gate_rejection", metadata: { reason: @role.pause_reason })

    respond_to_with_approval_stream("#{@role.title} approval has been rejected.")
  end

  private

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
