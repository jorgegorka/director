class RoleRunsController < ApplicationController
  before_action :require_company!
  before_action :set_role
  before_action :set_role_run, only: [ :show, :cancel ]

  def index
    @role_runs = @role.role_runs.order(created_at: :desc).limit(50)
  end

  def show
  end

  def cancel
    if @role_run.terminal?
      redirect_to role_role_run_path(@role, @role_run), alert: "Run is already #{@role_run.status}."
      return
    end

    @role_run.cancel!
    redirect_to role_role_run_path(@role, @role_run), notice: "Run has been cancelled."
  end

  private

  def set_role
    @role = Current.company.roles.find(params[:role_id])
  end

  def set_role_run
    @role_run = @role.role_runs.find(params[:id])
  end
end
