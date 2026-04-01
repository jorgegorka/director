class DashboardController < ApplicationController
  before_action :require_company!

  def show
    @company = Current.company

    @all_tasks = Current.company.tasks.includes(:assignee, :creator).order(priority: :desc, created_at: :desc)
    @tasks_by_status = Task.statuses.keys.index_with { |_s| [] }
    @all_tasks.each { |t| @tasks_by_status[t.status] << t }

    @tasks_active = @tasks_by_status.except("completed", "cancelled").values.sum(&:size)
    @tasks_completed = @tasks_by_status["completed"].size
    @total_tasks = @all_tasks.size

    @roles = Current.company.roles.active.includes(:assigned_tasks)
    @total_roles = @roles.count
    @roles_online = @roles.where(status: [ :idle, :running ]).count
    @running_roles = @roles.where(status: :running).includes(role_runs: :task)
    @total_budget_cents = @roles.where.not(budget_cents: nil).sum(:budget_cents)
    @budget_roles = @roles.where.not(budget_cents: nil).order(:title)

    period_start = Date.current.beginning_of_month.beginning_of_day
    spend_by_role = Task.where(assignee_id: @budget_roles.select(:id))
      .where.not(cost_cents: nil)
      .where(created_at: period_start..)
      .group(:assignee_id)
      .sum(:cost_cents)
    @budget_roles.each { |r| r.preloaded_monthly_spend_cents = spend_by_role[r.id] || 0 }
    @total_spend_cents = spend_by_role.values.sum

    @mission = Current.company.goals.roots.ordered.first

    @activity_events = AuditEvent.for_company(Current.company)
    if params[:role_filter].present?
      if params[:role_filter] == "roles_only"
        @activity_events = @activity_events.where(actor_type: "Role")
      else
        role_id = params[:role_filter].to_i
        if role_id > 0
          @activity_events = @activity_events.where(actor_type: "Role", actor_id: role_id)
        end
      end
    end
    @activity_events = @activity_events.reverse_chronological.includes(:actor, :auditable).limit(50)
    @filter_roles = Current.company.roles.active.order(:title)
  end
end
