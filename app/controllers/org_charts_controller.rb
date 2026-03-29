class OrgChartsController < ApplicationController
  before_action :require_company!

  def show
    @roles = Current.company.roles.order(:title)
    @roles_by_parent_id = @roles.group_by(&:parent_id)
    @root_roles = @roles_by_parent_id[nil] || []
  end
end
