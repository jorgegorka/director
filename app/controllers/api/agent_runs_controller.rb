module Api
  class AgentRunsController < ApplicationController
    include AgentApiAuthenticatable

    before_action :set_agent_run

    # POST /api/agent_runs/:id/result
    # Agent reports task completion with results.
    # Params: exit_code (integer), cost_cents (integer, optional), session_id (string, optional),
    #         summary (string, optional -- posted to task conversation)
    def result
      if @agent_run.terminal?
        render json: { error: "Run is already #{@agent_run.status}" }, status: :unprocessable_entity
        return
      end

      @agent_run.mark_completed!(
        exit_code: result_params[:exit_code]&.to_i,
        cost_cents: result_params[:cost_cents]&.to_i,
        claude_session_id: result_params[:session_id]
      )

      # Return agent to idle (CALLBACK-01)
      @agent_run.agent.update!(status: :idle) if @agent_run.agent.running?

      # Update task status if associated (CALLBACK-03)
      update_task_on_completion if @agent_run.task.present?

      # Budget enforcement if cost reported (CALLBACK-04)
      if result_params[:cost_cents].present? && result_params[:cost_cents].to_i > 0
        record_cost_on_task
        BudgetEnforcementService.check!(@agent_run.agent)
      end

      render json: {
        status: "ok",
        agent_run_id: @agent_run.id,
        agent_run_status: @agent_run.status,
        task_id: @agent_run.task_id
      }
    end

    # POST /api/agent_runs/:id/progress
    # Agent reports intermediate progress.
    # Params: message (string, required)
    def progress
      unless @agent_run.running?
        render json: { error: "Run is not currently running" }, status: :unprocessable_entity
        return
      end

      message = progress_params[:message]
      if message.blank?
        render json: { error: "message is required" }, status: :unprocessable_entity
        return
      end

      # Broadcast the progress message as a log line (CALLBACK-02)
      @agent_run.broadcast_line!("[progress] #{message}\n")

      render json: {
        status: "ok",
        agent_run_id: @agent_run.id
      }
    end

    private

    def set_agent_run
      # Find the agent run and verify it belongs to the authenticated agent
      @agent_run = AgentRun.find_by(id: params[:id])

      unless @agent_run
        render json: { error: "Agent run not found" }, status: :not_found
        return
      end

      unless @agent_run.agent_id == @current_agent&.id
        render json: { error: "Agent run does not belong to this agent" }, status: :forbidden
      end
    end

    def result_params
      params.permit(:exit_code, :cost_cents, :session_id, :summary)
    end

    def progress_params
      params.permit(:message)
    end

    def update_task_on_completion
      task = @agent_run.task

      # Update task status to completed (CALLBACK-03)
      task.update!(status: :completed) unless task.completed?

      # Post completion message to task conversation (CALLBACK-03)
      summary = result_params[:summary].presence || "Task completed by #{@current_agent.name}."
      task.messages.create!(
        body: summary,
        author: @current_agent
      )
    end

    def record_cost_on_task
      return unless @agent_run.task.present?

      task = @agent_run.task
      cost = result_params[:cost_cents].to_i
      new_cost = (task.cost_cents || 0) + cost
      task.update!(cost_cents: new_cost)
    end
  end
end
