require "test_helper"

class AgentHeartbeatJobTest < ActiveSupport::TestCase
  setup do
    @agent = agents(:http_agent)
    @agent.update_columns(heartbeat_enabled: true, heartbeat_interval: 15)
  end

  test "creates heartbeat event for scheduled agent" do
    assert_difference -> { HeartbeatEvent.count }, 1 do
      AgentHeartbeatJob.new.perform(@agent.id)
    end
    event = HeartbeatEvent.last
    assert event.scheduled?
    assert_equal @agent, event.agent
  end

  test "skips agent that is not heartbeat_scheduled" do
    @agent.update_columns(heartbeat_enabled: false)
    assert_no_difference -> { HeartbeatEvent.count } do
      AgentHeartbeatJob.new.perform(@agent.id)
    end
  end

  test "skips terminated agent" do
    @agent.update_columns(status: Agent.statuses[:terminated])
    assert_no_difference -> { HeartbeatEvent.count } do
      AgentHeartbeatJob.new.perform(@agent.id)
    end
  end

  test "skips non-existent agent" do
    assert_no_difference -> { HeartbeatEvent.count } do
      AgentHeartbeatJob.new.perform(999999)
    end
  end
end
