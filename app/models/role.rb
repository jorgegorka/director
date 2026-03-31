class Role < ApplicationRecord
  include Tenantable
  include TreeHierarchy
  include Notifiable
  include Auditable
  include ConfigVersioned
  include Roles::Hiring

  has_many :role_skills, dependent: :destroy, inverse_of: :role
  has_many :skills, through: :role_skills
  has_many :goal_evaluations, dependent: :destroy
  has_many :goals, dependent: :nullify
  has_many :assigned_tasks, class_name: "Task", foreign_key: :assignee_id, inverse_of: :assignee, dependent: :nullify
  has_many :heartbeat_events, dependent: :destroy
  has_many :approval_gates, dependent: :destroy
  has_many :role_hooks, dependent: :destroy
  has_many :role_runs, dependent: :destroy
  has_many :role_documents, dependent: :destroy, inverse_of: :role
  has_many :documents, through: :role_documents

  enum :adapter_type, { http: 0, process: 1, claude_local: 2 }
  enum :status, { idle: 0, running: 1, paused: 2, error: 3, terminated: 4, pending_approval: 5 }

  validates :title, presence: true,
                    uniqueness: { scope: :company_id, message: "already exists in this company" }
  validates :adapter_type, presence: true, if: :agent_configured?
  validates :adapter_config, presence: true, if: :agent_configured?
  validates :heartbeat_interval, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :budget_cents, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :validate_adapter_config_schema, if: :agent_configured?

  scope :active, -> { where.not(status: [ :terminated ]) }
  scope :agent_configured, -> { where.not(adapter_type: nil) }

  attr_writer :preloaded_monthly_spend_cents

  validates :working_directory, format: { with: /\A\//, message: "must be an absolute path" }, allow_blank: true

  before_validation :inherit_parent_working_directory, on: :create
  before_create :generate_api_token, if: :agent_configured?
  before_destroy :reparent_children
  after_save :assign_default_skills, if: :first_agent_configuration?
  after_commit :sync_heartbeat_schedule, if: :heartbeat_config_changed?
  after_commit :broadcast_dashboard_update, if: :saved_change_to_status?

  def self.default_skill_keys_for(role_title)
    default_skills_config.fetch(role_title.to_s.downcase.strip, [])
  end

  def self.default_skills_config
    @default_skills_config ||= YAML.load_file(Rails.root.join("config/default_skills.yml"))
  end

  def self.generate_unique_api_token
    loop do
      token = SecureRandom.base58(24)
      break token unless exists?(api_token: token)
    end
  end

  def regenerate_api_token!
    update!(api_token: self.class.generate_unique_api_token)
  end

  def adapter_class
    AdapterRegistry.for(adapter_type)
  end

  def agent_configured?
    adapter_type.present?
  end

  def subordinate_roles
    children.active
  end

  def manager_role
    parent_role = parent
    while parent_role
      return parent_role if parent_role.online?
      parent_role = parent_role.parent
    end
    nil
  end

  def online?
    agent_configured? && (idle? || running?)
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

  def latest_session_id
    pick_session(role_runs)
  end

  def latest_session_id_for(task)
    return latest_session_id if task.nil?

    pick_session(role_runs.where(task_id: task.id)) ||
      (task.goal_id.present? &&
        pick_session(role_runs.where(task_id: Task.where(goal_id: task.goal_id).where.not(id: task.id).select(:id)))) ||
      nil
  end

  def all_documents
    skill_doc_ids = SkillDocument.where(skill_id: skill_ids).select(:document_id)

    Document.for_current_company
      .where(id: documents.select(:id))
      .or(Document.for_current_company.where(id: skill_doc_ids))
  end

  def gate_enabled?(action_type)
    approval_gates.any? { |g| g.enabled? && g.action_type == action_type.to_s }
  end

  def has_any_gates?
    approval_gates.any?(&:enabled?)
  end

  def governance_attributes
    %w[title description job_spec parent_id budget_cents budget_period_start status working_directory]
  end

  private

  def pick_session(scope)
    scope.where.not(claude_session_id: nil)
         .order(created_at: :desc)
         .pick(:claude_session_id)
  end

  def inherit_parent_working_directory
    self.working_directory = parent&.working_directory if working_directory.blank?
  end

  def broadcast_dashboard_update
    broadcast_overview_stats
    broadcast_role_status
  end

  def broadcast_role_status
    Turbo::StreamsChannel.broadcast_replace_to(
      "role_#{id}",
      target: "role-status-badge-#{id}",
      partial: "roles/status_badge",
      locals: { role: self }
    )
  end

  def broadcast_overview_stats
    company = Company.find(company_id)
    roles = company.roles.active
    Turbo::StreamsChannel.broadcast_replace_to(
      "dashboard_company_#{company_id}",
      target: "dashboard-overview-stats",
      partial: "dashboard/overview_stats",
      locals: {
        total_roles: roles.count,
        roles_online: roles.where(status: [ :idle, :running ]).count,
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
    Heartbeats::ScheduleManager.sync(self)
  end

  def validate_adapter_config_schema
    return if adapter_config.blank?
    required_keys = AdapterRegistry.required_config_keys(adapter_type)
    missing = required_keys - adapter_config.keys.map(&:to_s)
    if missing.any?
      errors.add(:adapter_config, "missing required keys: #{missing.join(', ')}")
    end
  end

  def first_agent_configuration?
    saved_change_to_adapter_type? && adapter_type.present? && adapter_type_before_last_save.nil?
  end

  def assign_default_skills
    skill_keys = self.class.default_skill_keys_for(title)
    return if skill_keys.empty?

    company_skills = company.skills.where(key: skill_keys)
    existing_skill_ids = role_skills.where(skill: company_skills).pluck(:skill_id)

    company_skills.each do |skill|
      next if existing_skill_ids.include?(skill.id)
      role_skills.create!(skill: skill)
    end
  end

  def reparent_children
    if parent_id.present? && !Role.exists?(parent_id)
      children.update_all(parent_id: nil)
    else
      children.update_all(parent_id: parent_id)
    end
  end
end
