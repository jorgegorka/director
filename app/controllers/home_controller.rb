class HomeController < ApplicationController
  before_action :require_company!

  def show
    @company = Current.company
  end
end
