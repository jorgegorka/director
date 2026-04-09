class Roles::TerminationsController < ApplicationController
  include Roles::OrgChartStreamable

  def create
    if @role.terminated?
      redirect_to @role, alert: "#{@role.title} is already terminated."
      return
    end

    @role.update!(status: :terminated)
    @role.record_audit_event!(actor: Current.user, action: "role_terminated")

    respond_to_with_org_chart_node(@role, "#{@role.title} has been terminated.")
  end
end
