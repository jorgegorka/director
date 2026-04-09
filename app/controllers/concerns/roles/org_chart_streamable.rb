module Roles::OrgChartStreamable
  extend ActiveSupport::Concern

  included do
    before_action :require_project!
    before_action :set_role
  end

  private

  def set_role
    @role = Current.project.roles
      .includes(:skills, :approval_gates, :role_skills, :role_category, children: [ :skills, :role_category ])
      .find(params[:role_id])
  end

  def respond_to_with_org_chart_node(role, notice)
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace("org-chart-node-#{role.id}", partial: "roles/org_chart_node", locals: { role: role }) }
      format.html { redirect_to role, notice: notice }
    end
  end
end
