class OrgChartsController < ApplicationController
  before_action :require_company!

  def show
    @roles = Current.company.roles.includes(:parent, :children, :agent).order(:title)
    @root_roles = @roles.select(&:root?)
  end
end
