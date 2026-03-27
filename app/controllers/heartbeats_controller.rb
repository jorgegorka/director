class HeartbeatsController < ApplicationController
  before_action :require_company!
  before_action :set_agent

  def index
    page = [ params[:page].to_i, 1 ].max
    per_page = 25
    @heartbeat_events = @agent.heartbeat_events
                              .reverse_chronological
                              .offset((page - 1) * per_page)
                              .limit(per_page)
    @total_count = @agent.heartbeat_events.count
    @current_page = page
    @total_pages = (@total_count.to_f / per_page).ceil
  end

  private

  def set_agent
    @agent = Current.company.agents.find(params[:agent_id])
  end
end
