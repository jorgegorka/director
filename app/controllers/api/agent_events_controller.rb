module Api
  class AgentEventsController < ApplicationController
    include AgentApiAuthenticatable

    # GET /api/agent/events
    # Returns queued (pending) heartbeat events for the authenticated agent.
    # Process/bash agents poll this endpoint to pick up their events.
    def index
      events = @current_agent.heartbeat_events.queued.chronological
      render json: {
        agent_id: @current_agent.id,
        agent_name: @current_agent.name,
        events: events.map { |e| serialize_event(e) }
      }
    end

    # POST /api/agent/events/:id/acknowledge
    # Agent acknowledges receipt of an event, marking it as delivered.
    def acknowledge
      event = @current_agent.heartbeat_events.queued.find_by(id: params[:id])

      if event
        event.mark_delivered!(response: acknowledge_params)
        render json: { status: "ok", event_id: event.id }
      else
        render json: { error: "Event not found or already processed" }, status: :not_found
      end
    end

    private

    # Auth handled by AgentApiAuthenticatable concern (sets @current_agent and Current.company)

    def serialize_event(event)
      {
        id: event.id,
        trigger_type: event.trigger_type,
        trigger_source: event.trigger_source,
        request_payload: event.request_payload,
        created_at: event.created_at.iso8601
      }
    end

    def acknowledge_params
      params.permit(:response_status, :actions_taken).to_h
    end
  end
end
