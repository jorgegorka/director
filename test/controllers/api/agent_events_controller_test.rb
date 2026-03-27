require "test_helper"

class Api::AgentEventsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @process_agent = agents(:process_agent)
    @http_agent = agents(:http_agent)
    @queued_event = heartbeat_events(:queued_event)
  end

  # --- Authentication ---

  test "returns unauthorized without Bearer token" do
    get api_events_url, as: :json
    assert_response :unauthorized
    assert_equal "Unauthorized", response.parsed_body["error"]
  end

  test "returns unauthorized with invalid token" do
    get api_events_url, headers: bearer_headers("invalid_token"), as: :json
    assert_response :unauthorized
  end

  # --- Index (polling) ---

  test "returns queued events for authenticated agent" do
    get api_events_url, headers: bearer_headers(@process_agent.api_token), as: :json
    assert_response :success
    body = response.parsed_body
    assert_equal @process_agent.id, body["agent_id"]
    assert_equal @process_agent.name, body["agent_name"]
    assert body["events"].is_a?(Array)
    # process_agent has one queued event in fixtures
    queued_events = body["events"]
    assert queued_events.any? { |e| e["id"] == @queued_event.id }
  end

  test "does not return delivered events" do
    get api_events_url, headers: bearer_headers(@http_agent.api_token), as: :json
    assert_response :success
    body = response.parsed_body
    # http_agent has delivered and failed events, but no queued ones
    assert_equal [], body["events"]
  end

  test "returns events in chronological order" do
    # Create a second queued event for process_agent
    second_event = HeartbeatEvent.create!(
      agent: @process_agent,
      trigger_type: :mention,
      status: :queued,
      trigger_source: "Message#99",
      request_payload: { trigger: "mention" }
    )
    get api_events_url, headers: bearer_headers(@process_agent.api_token), as: :json
    assert_response :success
    events = response.parsed_body["events"]
    assert events.length >= 2
    # Verify chronological: first event created_at <= second event created_at
    timestamps = events.map { |e| e["created_at"] }
    assert_equal timestamps, timestamps.sort
  end

  test "event payload includes trigger details" do
    get api_events_url, headers: bearer_headers(@process_agent.api_token), as: :json
    event_data = response.parsed_body["events"].find { |e| e["id"] == @queued_event.id }
    assert event_data.present?
    assert_equal "task_assigned", event_data["trigger_type"]
    assert event_data["trigger_source"].present?
    assert event_data["request_payload"].present?
    assert event_data["created_at"].present?
  end

  # --- Acknowledge ---

  test "acknowledges a queued event" do
    post acknowledge_api_event_url(@queued_event),
         headers: bearer_headers(@process_agent.api_token),
         as: :json
    assert_response :success
    assert_equal "ok", response.parsed_body["status"]

    @queued_event.reload
    assert @queued_event.delivered?
    assert @queued_event.delivered_at.present?
  end

  test "cannot acknowledge event belonging to another agent" do
    post acknowledge_api_event_url(@queued_event),
         headers: bearer_headers(@http_agent.api_token),
         as: :json
    assert_response :not_found

    @queued_event.reload
    assert @queued_event.queued?  # unchanged
  end

  test "cannot acknowledge already delivered event" do
    delivered_event = heartbeat_events(:task_assigned_event)
    post acknowledge_api_event_url(delivered_event),
         headers: bearer_headers(@http_agent.api_token),
         as: :json
    assert_response :not_found
  end

  test "returns not found for non-existent event" do
    post acknowledge_api_event_url(id: 999999),
         headers: bearer_headers(@process_agent.api_token),
         as: :json
    assert_response :not_found
  end

  private

  def bearer_headers(token)
    { "Authorization" => "Bearer #{token}" }
  end
end
