require "test_helper"

class HeartbeatScheduleManagerTest < ActiveSupport::TestCase
  # HeartbeatScheduleManager interacts with SolidQueue::RecurringTask which lives in a
  # separate queue database (SQLite in production). In dev/test the table is absent from
  # the primary DB. We inject a FakeTaskStore to test the business logic without the
  # queue schema, using HeartbeatScheduleManager.task_store class attribute.

  class FakeTask
    attr_accessor :key, :class_name, :schedule, :arguments, :static, :description

    def initialize(key:)
      @key = key
    end

    def assign_attributes(attrs)
      attrs.each { |k, v| public_send(:"#{k}=", v) }
    end

    def save!
      FakeTaskStore.records[key] = self
    end

    def destroy
      FakeTaskStore.records.delete(key)
    end
  end

  class FakeTaskStore
    cattr_accessor :records
    self.records = {}

    def self.new(key:)
      FakeTask.new(key: key)
    end

    def self.find_by(key:)
      records[key]
    end

    def self.count
      records.size
    end

    def self.exists?(key:)
      records.key?(key)
    end
  end

  setup do
    @agent = agents(:http_agent)
    FakeTaskStore.records = {}
    HeartbeatScheduleManager.task_store = FakeTaskStore
  end

  teardown do
    HeartbeatScheduleManager.task_store = nil
  end

  test "creates recurring task when agent has schedule enabled" do
    @agent.update_columns(heartbeat_enabled: true, heartbeat_interval: 15)

    assert_difference -> { FakeTaskStore.count }, 1 do
      HeartbeatScheduleManager.sync(@agent)
    end

    task = FakeTaskStore.find_by(key: "agent_heartbeat_#{@agent.id}")
    assert task.present?
    assert_equal "AgentHeartbeatJob", task.class_name
    assert_equal "every 15 minutes", task.schedule
    assert_equal false, task.static
    assert_equal [ @agent.id ], task.arguments
  end

  test "updates existing recurring task when interval changes" do
    @agent.update_columns(heartbeat_enabled: true, heartbeat_interval: 15)
    HeartbeatScheduleManager.sync(@agent)

    @agent.update_columns(heartbeat_interval: 30)
    assert_no_difference -> { FakeTaskStore.count } do
      HeartbeatScheduleManager.sync(@agent)
    end

    task = FakeTaskStore.find_by(key: "agent_heartbeat_#{@agent.id}")
    assert_equal "every 30 minutes", task.schedule
  end

  test "removes recurring task when schedule is disabled" do
    @agent.update_columns(heartbeat_enabled: true, heartbeat_interval: 15)
    HeartbeatScheduleManager.sync(@agent)
    assert FakeTaskStore.exists?(key: "agent_heartbeat_#{@agent.id}")

    @agent.update_columns(heartbeat_enabled: false)
    HeartbeatScheduleManager.sync(@agent)
    assert_not FakeTaskStore.exists?(key: "agent_heartbeat_#{@agent.id}")
  end

  test "removes recurring task when interval is nil" do
    @agent.update_columns(heartbeat_enabled: true, heartbeat_interval: 15)
    HeartbeatScheduleManager.sync(@agent)

    @agent.update_columns(heartbeat_interval: nil)
    HeartbeatScheduleManager.sync(@agent)
    assert_not FakeTaskStore.exists?(key: "agent_heartbeat_#{@agent.id}")
  end

  test "remove class method destroys task" do
    @agent.update_columns(heartbeat_enabled: true, heartbeat_interval: 15)
    HeartbeatScheduleManager.sync(@agent)
    assert FakeTaskStore.exists?(key: "agent_heartbeat_#{@agent.id}")

    HeartbeatScheduleManager.remove(@agent)
    assert_not FakeTaskStore.exists?(key: "agent_heartbeat_#{@agent.id}")
  end

  test "remove does nothing when no task exists" do
    assert_nothing_raised do
      HeartbeatScheduleManager.remove(@agent)
    end
  end

  test "sync does nothing when solid queue not available" do
    HeartbeatScheduleManager.task_store = nil  # disable fake store so guard fires
    @agent.update_columns(heartbeat_enabled: true, heartbeat_interval: 15)

    # With no task_store and no real SolidQueue table, sync should be a no-op
    assert_nothing_raised do
      HeartbeatScheduleManager.sync(@agent)
    end
    assert_equal 0, FakeTaskStore.records.size
  end
end
