class AgentRunsController < ApplicationController
  before_action :require_company!
  before_action :set_agent
  before_action :set_agent_run, only: [ :show ]

  def index
    @agent_runs = @agent.agent_runs.order(created_at: :desc).limit(50)
  end

  def show
  end

  private

  def set_agent
    @agent = Current.company.agents.find(params[:agent_id])
  end

  def set_agent_run
    @agent_run = @agent.agent_runs.find(params[:id])
  end
end
