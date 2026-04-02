class Dashboards::TasksController < ApplicationController
  before_action :require_company!
  layout false

  def index
    @all_tasks = Current.company.tasks.includes(:assignee, :creator).order(priority: :desc, created_at: :desc)
    @tasks_by_status = Task.statuses.keys.index_with { |_s| [] }
    @all_tasks.each { |t| @tasks_by_status[t.status] << t }
  end
end
