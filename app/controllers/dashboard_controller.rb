class DashboardController < ApplicationController
  before_action :require_company!

  def show
    @overview = Dashboard::Overview.new(Current.company)
  end
end
