class Dashboards::TasksController < ApplicationController
  before_action :require_company!
  layout false

  def index
    @task_board = Dashboard::TaskBoard.new(Current.company)
  end
end
