require "test_helper"

class WakeAgentServiceTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @http_agent = agents(:http_agent)
    @process_agent = agents(:process_agent)
    @claude_agent = agents(:claude_agent)
  end

  test "creates heartbeat event for http agent with delivered status" do
    event = WakeAgentService.call(
      agent: @http_agent,
      trigger_type: :scheduled,
      trigger_source: "schedule"
    )
    assert event.persisted?
    assert event.delivered?
    assert event.scheduled?
    assert_equal "schedule", event.trigger_source
    assert event.delivered_at.present?
  end

  test "creates heartbeat event for process agent with queued status" do
    event = WakeAgentService.call(
      agent: @process_agent,
      trigger_type: :task_assigned,
      trigger_source: "Task#42"
    )
    assert event.persisted?
    assert event.queued?
    assert event.task_assigned?
    assert_equal "Task#42", event.trigger_source
  end

  test "creates heartbeat event for claude_local agent with queued status" do
    event = WakeAgentService.call(
      agent: @claude_agent,
      trigger_type: :mention,
      trigger_source: "Message#7"
    )
    assert event.persisted?
    assert event.queued?
    assert event.mention?
  end

  test "updates agent last_heartbeat_at" do
    assert_changes -> { @http_agent.reload.last_heartbeat_at } do
      WakeAgentService.call(agent: @http_agent, trigger_type: :scheduled)
    end
  end

  test "returns nil for terminated agent" do
    @http_agent.update_column(:status, Agent.statuses[:terminated])
    result = WakeAgentService.call(agent: @http_agent, trigger_type: :scheduled)
    assert_nil result
  end

  test "request_payload includes trigger context" do
    event = WakeAgentService.call(
      agent: @http_agent,
      trigger_type: :task_assigned,
      trigger_source: "Task#99",
      context: { task_id: 99, task_title: "Do something" }
    )
    assert_equal "task_assigned", event.request_payload["trigger"]
    assert_equal 99, event.request_payload["task_id"]
    assert_equal "Do something", event.request_payload["task_title"]
    assert_equal @http_agent.id, event.request_payload["agent_id"]
  end

  test "increments heartbeat_event count" do
    assert_difference -> { HeartbeatEvent.count }, 1 do
      WakeAgentService.call(agent: @http_agent, trigger_type: :scheduled)
    end
  end

  # --- AgentRun creation ---

  test "creates AgentRun record when waking agent" do
    assert_difference -> { AgentRun.count }, 1 do
      WakeAgentService.call(
        agent: @http_agent,
        trigger_type: :task_assigned,
        trigger_source: "Task#99",
        context: { task_id: tasks(:fix_login_bug).id }
      )
    end

    run = AgentRun.last
    assert run.queued?
    assert_equal @http_agent, run.agent
    assert_equal tasks(:fix_login_bug), run.task
    assert_equal @http_agent.company_id, run.company_id
    assert_equal "task_assigned", run.trigger_type
  end

  test "creates AgentRun with nil task for taskless triggers" do
    WakeAgentService.call(
      agent: @claude_agent,
      trigger_type: :scheduled,
      trigger_source: "schedule"
    )

    run = AgentRun.last
    assert run.queued?
    assert_nil run.task
    assert_equal "scheduled", run.trigger_type
  end

  test "enqueues ExecuteAgentJob when waking agent" do
    assert_enqueued_with(job: ExecuteAgentJob, queue: "execution") do
      WakeAgentService.call(
        agent: @http_agent,
        trigger_type: :task_assigned,
        context: { task_id: tasks(:fix_login_bug).id }
      )
    end
  end

  test "creates both HeartbeatEvent and AgentRun" do
    assert_difference -> { HeartbeatEvent.count }, 1 do
      assert_difference -> { AgentRun.count }, 1 do
        WakeAgentService.call(
          agent: @http_agent,
          trigger_type: :task_assigned,
          context: { task_id: tasks(:fix_login_bug).id }
        )
      end
    end
  end

  test "does not create AgentRun for terminated agent" do
    @http_agent.update_column(:status, Agent.statuses[:terminated])
    assert_no_difference -> { AgentRun.count } do
      WakeAgentService.call(agent: @http_agent, trigger_type: :scheduled)
    end
  end

  test "handles string task_id from context" do
    WakeAgentService.call(
      agent: @http_agent,
      trigger_type: :task_assigned,
      context: { "task_id" => tasks(:fix_login_bug).id.to_s }
    )

    run = AgentRun.last
    assert_equal tasks(:fix_login_bug), run.task
  end
end
