module Api
  class AgentCostsController < ApplicationController
    include AgentApiAuthenticatable

    def cost
      task = find_agent_task
      return unless task

      if @current_agent.paused? && @current_agent.pause_reason&.include?("Budget exhausted")
        render json: { error: "Agent is paused due to budget exhaustion" }, status: :forbidden
        return
      end

      cost_cents = cost_params[:cost_cents].to_i

      if cost_cents < 0
        render json: { error: "cost_cents must be non-negative" }, status: :unprocessable_entity
        return
      end

      # Accumulate cost (add to existing, not replace)
      new_cost = (task.cost_cents || 0) + cost_cents
      task.update!(cost_cents: new_cost)

      # Record audit event for cost
      task.record_audit_event!(
        actor: @current_agent,
        action: "cost_recorded",
        metadata: {
          cost_cents: cost_cents,
          total_cost_cents: new_cost,
          agent_name: @current_agent.name
        }
      )

      # Trigger budget enforcement check
      BudgetEnforcementService.check!(@current_agent)

      render json: {
        status: "ok",
        task_id: task.id,
        cost_cents: cost_cents,
        total_cost_cents: new_cost,
        agent_budget: budget_summary
      }
    end

    private

    def find_agent_task
      task = Current.company.tasks.find_by(id: params[:id])
      unless task
        render json: { error: "Task not found" }, status: :not_found
        return nil
      end

      unless task.assignee_id == @current_agent.id
        render json: { error: "Task is not assigned to this agent" }, status: :forbidden
        return nil
      end

      task
    end

    def cost_params
      params.permit(:cost_cents)
    end

    def budget_summary
      return nil unless @current_agent.budget_configured?
      @current_agent.reload
      {
        budget_cents: @current_agent.budget_cents,
        spent_cents: @current_agent.monthly_spend_cents,
        remaining_cents: @current_agent.budget_remaining_cents,
        utilization: @current_agent.budget_utilization,
        exhausted: @current_agent.budget_exhausted?
      }
    end
  end
end
