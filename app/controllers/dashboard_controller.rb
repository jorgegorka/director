class DashboardController < ApplicationController
  before_action :require_project!

  def show
    @dashboard = Dashboard::GoalsDashboard.new(Current.project)
  end
end
