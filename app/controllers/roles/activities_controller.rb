class Roles::ActivitiesController < ApplicationController
  include Roles::OrgChartStreamable

  def create
    if @role.terminated?
      redirect_to @role, alert: "Cannot run a terminated role."
      return
    end

    if @role.role_runs.active.exists?
      redirect_to @role, alert: "#{@role.title} already has an active run."
      return
    end

    Roles::Waking.call(
      role: @role,
      trigger_type: :manual,
      trigger_source: "Manual run by #{Current.user.email_address}"
    )

    respond_to_with_org_chart_node(@role.reload, "#{@role.title} has been started.")
  end
end
