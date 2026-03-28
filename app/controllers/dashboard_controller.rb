class DashboardController < ApplicationController
  before_action :require_company!

  def show
    @company = Current.company
    @agents = Current.company.agents.active.includes(:assigned_tasks)
    @total_agents = @agents.count
    @agents_online = @agents.where(status: [ :idle, :running ]).count
    @tasks_active = Current.company.tasks.active.count
    @tasks_completed = Current.company.tasks.completed.count
    @total_tasks = Current.company.tasks.count
    @total_budget_cents = @agents.where.not(budget_cents: nil).sum(:budget_cents)
    @total_spend_cents = @agents.sum(&:monthly_spend_cents)
    @mission = Current.company.goals.roots.ordered.first
    @budget_agents = @agents.where.not(budget_cents: nil).order(:name)
  end
end
