class HeartbeatsController < ApplicationController
  before_action :require_company!
  before_action :set_role

  def index
    page = [ params[:page].to_i, 1 ].max
    per_page = 25
    @heartbeat_events = @role.heartbeat_events
                             .reverse_chronological
                             .offset((page - 1) * per_page)
                             .limit(per_page)
    @total_count = @role.heartbeat_events.count
    @current_page = page
    @total_pages = (@total_count.to_f / per_page).ceil
  end

  private

  def set_role
    @role = Current.company.roles.find(params[:role_id])
  end
end
