class HeartbeatScheduleManager
  TASK_KEY_PREFIX = "agent_heartbeat_".freeze

  # task_store can be overridden in tests
  class_attribute :task_store
  self.task_store = nil

  def self.sync(agent)
    new(agent).sync
  end

  def self.remove(agent)
    new(agent).remove
  end

  def initialize(agent)
    @agent = agent
  end

  def sync
    return unless solid_queue_available?

    if @agent.heartbeat_scheduled?
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
    "#{TASK_KEY_PREFIX}#{@agent.id}"
  end

  def schedule_expression
    "every #{@agent.heartbeat_interval} minutes"
  end

  def upsert_recurring_task
    task = find_recurring_task || recurring_task_class.new(key: task_key)
    task.assign_attributes(
      class_name: "AgentHeartbeatJob",
      schedule: schedule_expression,
      arguments: [ @agent.id ],
      static: false,
      description: "Heartbeat for agent: #{@agent.name} (#{@agent.id})"
    )
    task.save!
    task
  end

  def find_recurring_task
    recurring_task_class.find_by(key: task_key)
  end
end
