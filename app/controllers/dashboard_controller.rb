class DashboardController < ApplicationController
  before_action :require_company!

  def show
    @company = Current.company

    # Load all tasks once; derive counts and kanban grouping from in-memory collection
    @all_tasks = Current.company.tasks.includes(:assignee, :creator).order(priority: :desc, created_at: :desc)
    @tasks_by_status = Task.statuses.keys.index_with { |_s| [] }
    @all_tasks.each { |t| @tasks_by_status[t.status] << t }

    @tasks_active = @tasks_by_status.except("completed", "cancelled").values.sum(&:size)
    @tasks_completed = @tasks_by_status["completed"].size
    @total_tasks = @all_tasks.size

    @agents = Current.company.agents.active.includes(:assigned_tasks)
    @total_agents = @agents.count
    @agents_online = @agents.where(status: [ :idle, :running ]).count
    @total_budget_cents = @agents.where.not(budget_cents: nil).sum(:budget_cents)
    @total_spend_cents = @agents.sum(&:monthly_spend_cents)
    @mission = Current.company.goals.roots.ordered.first
    @budget_agents = @agents.where.not(budget_cents: nil).order(:name)

    @activity_events = AuditEvent.for_company(Current.company)
    if params[:agent_filter].present?
      if params[:agent_filter] == "agents_only"
        @activity_events = @activity_events.where(actor_type: "Agent")
      else
        agent_id = params[:agent_filter].to_i
        if agent_id > 0
          @activity_events = @activity_events.where(actor_type: "Agent", actor_id: agent_id)
        end
      end
    end
    @activity_events = @activity_events.reverse_chronological.includes(:actor, :auditable).limit(50)
    @filter_agents = Current.company.agents.active.order(:name)
  end
end
