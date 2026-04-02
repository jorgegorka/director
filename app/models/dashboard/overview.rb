class Dashboard::Overview
  attr_reader :company

  def initialize(company)
    @company = company
  end

  def tasks_active_count
    @tasks_active_count ||= company.tasks.active.count
  end

  def tasks_completed_count
    @tasks_completed_count ||= company.tasks.completed.count
  end

  def total_roles_count
    @total_roles_count ||= active_roles.count
  end

  def roles_online_count
    @roles_online_count ||= active_roles.online.count
  end

  def running_roles
    @running_roles ||= active_roles.where(status: :running).includes(role_runs: :task)
  end

  def budget_roles
    @budget_roles ||= begin
      roles = active_roles.with_budget.order(:title)
      @_total_spend_cents = company.preload_monthly_spend(roles)
      roles
    end
  end

  def total_budget_cents
    @total_budget_cents ||= budget_roles.sum(:budget_cents)
  end

  def total_spend_cents
    budget_roles
    @_total_spend_cents
  end

  def mission
    @mission ||= company.goals.roots.ordered.first
  end

  def show_mission?
    mission.present?
  end

  def show_budget?
    budget_roles.any?
  end

  private
    def active_roles
      @active_roles ||= company.roles.active
    end
end
