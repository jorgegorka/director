class Agent < ApplicationRecord
  include Tenantable
  include Notifiable
  include Auditable
  include ConfigVersioned

  has_many :agent_skills, dependent: :destroy, inverse_of: :agent
  has_many :skills, through: :agent_skills
  has_many :roles, dependent: :nullify
  has_many :assigned_tasks, class_name: "Task", foreign_key: :assignee_id, inverse_of: :assignee, dependent: :nullify
  has_many :heartbeat_events, dependent: :destroy
  has_many :approval_gates, dependent: :destroy

  enum :adapter_type, { http: 0, process: 1, claude_local: 2 }
  enum :status, { idle: 0, running: 1, paused: 2, error: 3, terminated: 4, pending_approval: 5 }

  validates :name, presence: true,
                   uniqueness: { scope: :company_id, message: "already exists in this company" }
  validates :adapter_type, presence: true
  validates :adapter_config, presence: true
  validates :heartbeat_interval, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :budget_cents, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :validate_adapter_config_schema

  scope :active, -> { where.not(status: [ :terminated ]) }

  attr_writer :preloaded_monthly_spend_cents

  before_create :generate_api_token
  after_commit :sync_heartbeat_schedule, if: :heartbeat_config_changed?
  after_commit :broadcast_dashboard_update, if: :saved_change_to_status?

  def regenerate_api_token!
    update!(api_token: self.class.generate_unique_api_token)
  end

  def self.generate_unique_api_token
    loop do
      token = SecureRandom.base58(24)
      break token unless exists?(api_token: token)
    end
  end

  def adapter_class
    AdapterRegistry.for(adapter_type)
  end

  def current_company_role
    roles.for_current_company.first
  end

  def subordinate_agents
    role = current_company_role
    return Agent.none unless role

    ids = role.children.where.not(agent_id: nil).pluck(:agent_id)
    Agent.where(id: ids).active
  end

  def manager_agent
    role = current_company_role
    return nil unless role

    parent_role = role.parent
    while parent_role
      return parent_role.agent if parent_role.agent.present?
      parent_role = parent_role.parent
    end
    nil
  end

  def online?
    idle? || running?
  end

  def offline?
    !online?
  end

  def heartbeat_scheduled?
    heartbeat_enabled? && heartbeat_interval.present?
  end

  def budget_configured?
    budget_cents.present? && budget_cents > 0
  end

  def current_budget_period_start
    return nil unless budget_configured?
    (budget_period_start || Date.current.beginning_of_month)
  end

  def current_budget_period_end
    return nil unless budget_configured?
    current_budget_period_start.end_of_month
  end

  def reload(*)
    @monthly_spend_cents = nil
    remove_instance_variable(:@preloaded_monthly_spend_cents) if defined?(@preloaded_monthly_spend_cents)
    super
  end

  def monthly_spend_cents
    return 0 unless budget_configured?
    return @preloaded_monthly_spend_cents if defined?(@preloaded_monthly_spend_cents)

    @monthly_spend_cents ||= begin
      period_start = current_budget_period_start
      period_end = current_budget_period_end

      assigned_tasks
        .where.not(cost_cents: nil)
        .where(created_at: period_start.beginning_of_day..period_end.end_of_day)
        .sum(:cost_cents)
    end
  end

  def budget_remaining_cents
    return nil unless budget_configured?
    [ budget_cents - monthly_spend_cents, 0 ].max
  end

  def budget_utilization
    return 0.0 unless budget_configured?
    return 0.0 if budget_cents.zero?
    [ (monthly_spend_cents.to_f / budget_cents * 100), 100.0 ].min.round(1)
  end

  def budget_exhausted?
    budget_configured? && monthly_spend_cents >= budget_cents
  end

  def budget_alert_threshold?
    budget_configured? && budget_utilization >= 80.0
  end

  def gate_enabled?(action_type)
    approval_gates.any? { |g| g.enabled? && g.action_type == action_type.to_s }
  end

  def has_any_gates?
    approval_gates.any?(&:enabled?)
  end

  def governance_attributes
    %w[name budget_cents budget_period_start status]
  end

  private

  def broadcast_dashboard_update
    broadcast_overview_stats
  end

  def broadcast_overview_stats
    company = Company.find(company_id)
    agents = company.agents.active
    Turbo::StreamsChannel.broadcast_replace_to(
      "dashboard_company_#{company_id}",
      target: "dashboard-overview-stats",
      partial: "dashboard/overview_stats",
      locals: {
        total_agents: agents.count,
        agents_online: agents.where(status: [ :idle, :running ]).count,
        tasks_active: company.tasks.active.count,
        tasks_completed: company.tasks.completed.count
      }
    )
  end

  def generate_api_token
    self.api_token ||= self.class.generate_unique_api_token
  end

  def heartbeat_config_changed?
    saved_change_to_heartbeat_interval? || saved_change_to_heartbeat_enabled?
  end

  def sync_heartbeat_schedule
    HeartbeatScheduleManager.sync(self)
  end

  def validate_adapter_config_schema
    return if adapter_config.blank?
    required_keys = AdapterRegistry.required_config_keys(adapter_type)
    missing = required_keys - adapter_config.keys.map(&:to_s)
    if missing.any?
      errors.add(:adapter_config, "missing required keys: #{missing.join(', ')}")
    end
  end
end
