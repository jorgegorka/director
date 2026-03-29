class HeartbeatScheduleManager
  TASK_KEY_PREFIX = "role_heartbeat_".freeze

  class_attribute :task_store
  self.task_store = nil

  def self.sync(role)
    new(role).sync
  end

  def self.remove(role)
    new(role).remove
  end

  def initialize(role)
    @role = role
  end

  def sync
    return unless solid_queue_available?

    if @role.heartbeat_scheduled?
      upsert_recurring_task
    else
      remove
    end
  end

  def remove
    return unless solid_queue_available?

    existing = find_recurring_task
    existing&.destroy
  end

  private

  def solid_queue_available?
    return true if self.class.task_store

    defined?(SolidQueue::RecurringTask) &&
      ActiveRecord::Base.connection.table_exists?("solid_queue_recurring_tasks")
  rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid
    false
  end

  def recurring_task_class
    self.class.task_store || SolidQueue::RecurringTask
  end

  def task_key
    "#{TASK_KEY_PREFIX}#{@role.id}"
  end

  def schedule_expression
    "every #{@role.heartbeat_interval} minutes"
  end

  def upsert_recurring_task
    task = find_recurring_task || recurring_task_class.new(key: task_key)
    task.assign_attributes(
      class_name: "RoleHeartbeatJob",
      schedule: schedule_expression,
      arguments: [ @role.id ],
      static: false,
      description: "Heartbeat for role: #{@role.title} (#{@role.id})"
    )
    task.save!
    task
  end

  def find_recurring_task
    recurring_task_class.find_by(key: task_key)
  end
end
