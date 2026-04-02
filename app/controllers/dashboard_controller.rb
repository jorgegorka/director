class DashboardController < ApplicationController
  before_action :require_company!

  def show
    @company = Current.company
    roles = @company.roles.active

    @tasks_active = @company.tasks.active.count
    @tasks_completed = @company.tasks.completed.count

    @total_roles = roles.count
    @roles_online = roles.online.count
    @running_roles = roles.where(status: :running).includes(role_runs: :task)

    @budget_roles = roles.with_budget.order(:title)
    @total_budget_cents = @budget_roles.sum(:budget_cents)
    @total_spend_cents = @company.preload_monthly_spend(@budget_roles)

    @mission = @company.goals.roots.ordered.first
  end
end
