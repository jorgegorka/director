require "test_helper"

class TriggerableTaskTest < ActiveSupport::TestCase
  setup do
    @company = companies(:acme)
    @user = users(:one)
    @http_agent = agents(:http_agent)
    @claude_agent = agents(:claude_agent)
    @process_agent = agents(:process_agent)
  end

  # --- Task Assignment Triggers ---

  test "creating a task with assignee triggers wake event" do
    assert_difference -> { HeartbeatEvent.count }, 1 do
      Task.create!(
        title: "New task for agent",
        company: @company,
        creator: @user,
        assignee: @http_agent
      )
    end
    event = HeartbeatEvent.last
    assert event.task_assigned?
    assert_equal @http_agent, event.agent
    assert_match(/Task#/, event.trigger_source)
  end

  test "creating a task without assignee does not trigger wake event" do
    assert_no_difference -> { HeartbeatEvent.count } do
      Task.create!(
        title: "Unassigned task",
        company: @company,
        creator: @user
      )
    end
  end

  test "assigning agent to existing task triggers wake event" do
    task = Task.create!(title: "Unassigned", company: @company, creator: @user)
    assert_difference -> { HeartbeatEvent.count }, 1 do
      task.update!(assignee: @claude_agent)
    end
    event = HeartbeatEvent.last
    assert event.task_assigned?
    assert_equal @claude_agent, event.agent
    assert_equal "Task##{task.id}", event.trigger_source
  end

  test "reassigning task to different agent triggers wake for new agent" do
    task = Task.create!(title: "Assigned", company: @company, creator: @user, assignee: @http_agent)
    # Clear events from initial creation
    HeartbeatEvent.delete_all

    assert_difference -> { HeartbeatEvent.count }, 1 do
      task.update!(assignee: @claude_agent)
    end
    event = HeartbeatEvent.last
    assert_equal @claude_agent, event.agent
  end

  test "updating task without changing assignee does not trigger wake" do
    task = tasks(:design_homepage)
    assert_no_difference -> { HeartbeatEvent.count } do
      task.update!(title: "Updated title")
    end
  end

  test "unassigning task (setting assignee to nil) does not trigger wake" do
    task = Task.create!(title: "Assigned", company: @company, creator: @user, assignee: @http_agent)
    HeartbeatEvent.delete_all

    assert_no_difference -> { HeartbeatEvent.count } do
      task.update!(assignee: nil)
    end
  end

  test "does not trigger wake for terminated agent" do
    terminated_agent = Agent.create!(
      name: "Dead Agent",
      company: @company,
      adapter_type: :http,
      adapter_config: { "url" => "https://example.com" },
      status: :terminated
    )
    assert_no_difference -> { HeartbeatEvent.count } do
      Task.create!(title: "Task for dead", company: @company, creator: @user, assignee: terminated_agent)
    end
  end

  test "task assignment trigger includes task context" do
    task = Task.create!(title: "Important work", company: @company, creator: @user, assignee: @http_agent)
    event = HeartbeatEvent.last
    assert_equal task.id, event.request_payload["task_id"]
    assert_equal "Important work", event.request_payload["task_title"]
  end
end

class TriggerableMentionTest < ActiveSupport::TestCase
  setup do
    @company = companies(:acme)
    @user = users(:one)
    @task = tasks(:design_homepage)
    @http_agent = agents(:http_agent)
    @claude_agent = agents(:claude_agent)
  end

  # --- Message @Mention Triggers ---

  test "message mentioning agent triggers wake event" do
    assert_difference -> { HeartbeatEvent.count }, 1 do
      Message.create!(
        task: @task,
        author: @user,
        body: "Hey @API Bot can you check this?"
      )
    end
    event = HeartbeatEvent.last
    assert event.mention?
    assert_equal @http_agent, event.agent
    assert_match(/Message#/, event.trigger_source)
  end

  test "message without mentions does not trigger wake" do
    assert_no_difference -> { HeartbeatEvent.count } do
      Message.create!(
        task: @task,
        author: @user,
        body: "Just a regular message with no mentions"
      )
    end
  end

  test "message mentioning multiple agents triggers multiple wake events" do
    assert_difference -> { HeartbeatEvent.count }, 2 do
      Message.create!(
        task: @task,
        author: @user,
        body: "Hey @API Bot and @Claude Assistant please review"
      )
    end
  end

  test "mention is case-insensitive" do
    assert_difference -> { HeartbeatEvent.count }, 1 do
      Message.create!(
        task: @task,
        author: @user,
        body: "Hey @api bot what do you think?"
      )
    end
    event = HeartbeatEvent.last
    assert_equal @http_agent, event.agent
  end

  test "mention of non-existent agent name does not trigger" do
    assert_no_difference -> { HeartbeatEvent.count } do
      Message.create!(
        task: @task,
        author: @user,
        body: "Hey @NonExistentBot can you help?"
      )
    end
  end

  test "mention of agent from different company does not trigger" do
    assert_no_difference -> { HeartbeatEvent.count } do
      Message.create!(
        task: @task,
        author: @user,
        body: "Hey @Widget Bot can you help?"
      )
    end
  end

  test "mention does not trigger for terminated agent" do
    @http_agent.update_column(:status, Agent.statuses[:terminated])
    assert_no_difference -> { HeartbeatEvent.count } do
      Message.create!(
        task: @task,
        author: @user,
        body: "Hey @API Bot are you there?"
      )
    end
  end

  test "mention event includes message context" do
    msg = Message.create!(
      task: @task,
      author: @user,
      body: "Hey @API Bot review this"
    )
    event = HeartbeatEvent.last
    assert_equal msg.id, event.request_payload["message_id"]
    assert_equal @task.id, event.request_payload["task_id"]
    assert_equal "user", event.request_payload["mentioned_by"]
  end
end
