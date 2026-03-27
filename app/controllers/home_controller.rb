class HomeController < ApplicationController
  before_action :require_company!

  def show
    @company = Current.company
    @mission = Current.company.goals.roots.ordered.first
  end
end
