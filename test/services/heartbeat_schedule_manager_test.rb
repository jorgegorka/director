require "test_helper"

class HeartbeatScheduleManagerTest < ActiveSupport::TestCase
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
    @role = roles(:developer)
    FakeTaskStore.records = {}
    HeartbeatScheduleManager.task_store = FakeTaskStore
  end

  teardown do
    HeartbeatScheduleManager.task_store = nil
  end

  test "creates recurring task when role has schedule enabled" do
    @role.update_columns(heartbeat_enabled: true, heartbeat_interval: 15)

    assert_difference -> { FakeTaskStore.count }, 1 do
      HeartbeatScheduleManager.sync(@role)
    end

    task = FakeTaskStore.find_by(key: "role_heartbeat_#{@role.id}")
    assert task.present?
    assert_equal "RoleHeartbeatJob", task.class_name
    assert_equal "every 15 minutes", task.schedule
    assert_equal false, task.static
    assert_equal [ @role.id ], task.arguments
  end

  test "updates existing recurring task when interval changes" do
    @role.update_columns(heartbeat_enabled: true, heartbeat_interval: 15)
    HeartbeatScheduleManager.sync(@role)

    @role.update_columns(heartbeat_interval: 30)
    assert_no_difference -> { FakeTaskStore.count } do
      HeartbeatScheduleManager.sync(@role)
    end

    task = FakeTaskStore.find_by(key: "role_heartbeat_#{@role.id}")
    assert_equal "every 30 minutes", task.schedule
  end

  test "removes recurring task when schedule is disabled" do
    @role.update_columns(heartbeat_enabled: true, heartbeat_interval: 15)
    HeartbeatScheduleManager.sync(@role)
    assert FakeTaskStore.exists?(key: "role_heartbeat_#{@role.id}")

    @role.update_columns(heartbeat_enabled: false)
    HeartbeatScheduleManager.sync(@role)
    assert_not FakeTaskStore.exists?(key: "role_heartbeat_#{@role.id}")
  end

  test "removes recurring task when interval is nil" do
    @role.update_columns(heartbeat_enabled: true, heartbeat_interval: 15)
    HeartbeatScheduleManager.sync(@role)

    @role.update_columns(heartbeat_interval: nil)
    HeartbeatScheduleManager.sync(@role)
    assert_not FakeTaskStore.exists?(key: "role_heartbeat_#{@role.id}")
  end

  test "remove class method destroys task" do
    @role.update_columns(heartbeat_enabled: true, heartbeat_interval: 15)
    HeartbeatScheduleManager.sync(@role)
    assert FakeTaskStore.exists?(key: "role_heartbeat_#{@role.id}")

    HeartbeatScheduleManager.remove(@role)
    assert_not FakeTaskStore.exists?(key: "role_heartbeat_#{@role.id}")
  end

  test "remove does nothing when no task exists" do
    assert_nothing_raised do
      HeartbeatScheduleManager.remove(@role)
    end
  end

  test "sync does nothing when solid queue not available" do
    HeartbeatScheduleManager.task_store = nil
    @role.update_columns(heartbeat_enabled: true, heartbeat_interval: 15)

    assert_nothing_raised do
      HeartbeatScheduleManager.sync(@role)
    end
    assert_equal 0, FakeTaskStore.records.size
  end
end
