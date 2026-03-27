class OrgChartsController < ApplicationController
  before_action :require_company!

  def show
    @roles = Current.company.roles.includes(:parent, :children).order(:title)
    @root_roles = @roles.select(&:root?)
  end
end
