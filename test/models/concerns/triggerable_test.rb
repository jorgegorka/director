require "test_helper"

class TriggerableTaskTest < ActiveSupport::TestCase
  setup do
    @company = companies(:acme)
    @user = users(:one)
    @developer = roles(:developer)
    @cto = roles(:cto)
    @process_role = roles(:process_role)
  end

  # --- Task Assignment Triggers ---

  test "creating a task with assignee triggers wake event" do
    assert_difference -> { HeartbeatEvent.count }, 1 do
      Task.create!(
        title: "New task for role",
        company: @company,
        creator: @cto,
        assignee: @developer
      )
    end
    event = HeartbeatEvent.last
    assert event.task_assigned?
    assert_equal @developer, event.role
    assert_match(/Task#/, event.trigger_source)
  end

  test "creating a task without assignee does not trigger wake event" do
    assert_no_difference -> { HeartbeatEvent.count } do
      Task.create!(
        title: "Unassigned task",
        company: @company,
        creator: @cto
      )
    end
  end

  test "assigning role to existing task triggers wake event" do
    task = Task.create!(title: "Unassigned", company: @company, creator: @cto)
    assert_difference -> { HeartbeatEvent.count }, 1 do
      task.update!(assignee: @cto)
    end
    event = HeartbeatEvent.last
    assert event.task_assigned?
    assert_equal @cto, event.role
    assert_equal "Task##{task.id}", event.trigger_source
  end

  test "reassigning task to different role triggers wake for new role" do
    task = Task.create!(title: "Assigned", company: @company, creator: @cto, assignee: @developer)
    # Clear events from initial creation
    HeartbeatEvent.delete_all

    assert_difference -> { HeartbeatEvent.count }, 1 do
      task.update!(assignee: @cto)
    end
    event = HeartbeatEvent.last
    assert_equal @cto, event.role
  end

  test "updating task without changing assignee does not trigger wake" do
    task = tasks(:design_homepage)
    assert_no_difference -> { HeartbeatEvent.count } do
      task.update!(title: "Updated title")
    end
  end

  test "unassigning task (setting assignee to nil) does not trigger wake" do
    task = Task.create!(title: "Assigned", company: @company, creator: @cto, assignee: @developer)
    HeartbeatEvent.delete_all

    assert_no_difference -> { HeartbeatEvent.count } do
      task.update!(assignee: nil)
    end
  end

  test "does not trigger wake for terminated role" do
    terminated_role = Role.create!(
      role_category: role_categories(:worker),
      title: "Dead Role",
      company: @company,
      parent: @cto,
      adapter_type: :http,
      adapter_config: { "url" => "https://example.com" },
      status: :terminated
    )
    assert_no_difference -> { HeartbeatEvent.count } do
      Task.create!(title: "Task for dead", company: @company, creator: @cto, assignee: terminated_role)
    end
  end

  test "task assignment trigger includes task context" do
    task = Task.create!(title: "Important work", company: @company, creator: @cto, assignee: @developer)
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
    @developer = roles(:developer)
    @cto = roles(:cto)
  end

  # --- Message @Mention Triggers ---

  test "message mentioning role triggers wake event" do
    assert_difference -> { HeartbeatEvent.count }, 1 do
      Message.create!(
        task: @task,
        author: @user,
        body: "Hey @Senior Developer can you check this?"
      )
    end
    event = HeartbeatEvent.last
    assert event.mention?
    assert_equal @developer, event.role
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

  test "message mentioning multiple roles triggers multiple wake events" do
    assert_difference -> { HeartbeatEvent.count }, 2 do
      Message.create!(
        task: @task,
        author: @user,
        body: "Hey @Senior Developer and @CTO please review"
      )
    end
  end

  test "mention is case-insensitive" do
    assert_difference -> { HeartbeatEvent.count }, 1 do
      Message.create!(
        task: @task,
        author: @user,
        body: "Hey @senior developer what do you think?"
      )
    end
    event = HeartbeatEvent.last
    assert_equal @developer, event.role
  end

  test "mention of non-existent role title does not trigger" do
    assert_no_difference -> { HeartbeatEvent.count } do
      Message.create!(
        task: @task,
        author: @user,
        body: "Hey @NonExistentBot can you help?"
      )
    end
  end

  test "mention of role from different company does not trigger" do
    assert_no_difference -> { HeartbeatEvent.count } do
      Message.create!(
        task: @task,
        author: @user,
        body: "Hey @Operations Lead can you help?"
      )
    end
  end

  test "mention does not trigger for terminated role" do
    @developer.update_column(:status, Role.statuses[:terminated])
    assert_no_difference -> { HeartbeatEvent.count } do
      Message.create!(
        task: @task,
        author: @user,
        body: "Hey @Senior Developer are you there?"
      )
    end
  end

  test "mention event includes message context" do
    msg = Message.create!(
      task: @task,
      author: @user,
      body: "Hey @Senior Developer review this"
    )
    event = HeartbeatEvent.last
    assert_equal msg.id, event.request_payload["message_id"]
    assert_equal @task.id, event.request_payload["task_id"]
    assert_equal "user", event.request_payload["mentioned_by"]
  end
end
