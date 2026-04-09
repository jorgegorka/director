class Roles::PausesController < ApplicationController
  include Roles::OrgChartStreamable

  # pause
  def create
    if @role.paused?
      redirect_to @role, alert: "#{@role.title} is already paused."
      return
    end

    if @role.terminated?
      redirect_to @role, alert: "Cannot pause a terminated role."
      return
    end

    @role.update!(
      status: :paused,
      pause_reason: params[:reason].presence || "Manually paused by #{Current.user.email_address}",
      paused_at: Time.current
    )
    @role.record_audit_event!(actor: Current.user, action: "role_paused", metadata: { reason: @role.pause_reason })

    respond_to_with_org_chart_node(@role, "#{@role.title} has been paused.")
  end

  # resume
  def destroy
    unless @role.paused? || @role.pending_approval?
      redirect_to @role, alert: "#{@role.title} is not paused."
      return
    end

    @role.update!(
      status: :idle,
      pause_reason: nil,
      paused_at: nil
    )
    @role.record_audit_event!(actor: Current.user, action: "role_resumed")

    respond_to_with_org_chart_node(@role, "#{@role.title} has been resumed.")
  end
end
