class Dashboards::TasksController < DashboardController
  def index
    @current_tab = :tasks
    load_common_data
    @task_board = Dashboard::TaskBoard.new(Current.company)
    render "dashboard/show"
  end
end
