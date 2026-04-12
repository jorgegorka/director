class Role < ApplicationRecord
  include Tenantable
  include TreeHierarchy
  include Notifiable
  include Auditable
  include ConfigVersioned
  include Roles::Hiring
  include Roles::AgentConfiguration
  include Roles::Budgeting
  include Roles::Broadcasting
  include Roles::PromptBuilder

  belongs_to :role_category

  has_many :role_skills, dependent: :destroy, inverse_of: :role
  has_many :skills, through: :role_skills
  has_many :task_evaluations, dependent: :destroy
  has_many :created_tasks, class_name: "Task", foreign_key: :creator_id, inverse_of: :creator, dependent: :restrict_with_error
  has_many :assigned_tasks, class_name: "Task", foreign_key: :assignee_id, inverse_of: :assignee, dependent: :nullify
  has_many :reviewed_tasks, class_name: "Task", foreign_key: :reviewed_by_id, inverse_of: :reviewed_by, dependent: :nullify
  has_many :heartbeat_events, dependent: :destroy
  has_many :approval_gates, dependent: :destroy
  has_many :role_hooks, dependent: :destroy
  has_many :role_runs, dependent: :destroy

  enum :status, { idle: 0, running: 1, paused: 2, error: 3, terminated: 4, pending_approval: 5 }

  validates :title, presence: true,
                    uniqueness: { scope: :project_id, message: "already exists in this project" }
  validates :heartbeat_interval, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  scope :active, -> { where.not(status: [ :terminated ]) }
  scope :online, -> { where(status: [ :idle, :running ]) }
  scope :by_category, ->(category) { where(role_category: category) }
  scope :excluding_subtree, ->(role) { role.new_record? ? all : where.not(id: [ role.id, *role.descendant_ids ]) }

  validates :working_directory, format: { with: /\A\/[^\x00]*\z/, message: "must be an absolute path" }, allow_blank: true

  before_validation :inherit_parent_working_directory, on: :create
  before_validation :inherit_parent_adapter, on: :create
  before_destroy :reparent_children
  after_commit :sync_heartbeat_schedule, if: :heartbeat_config_changed?
  after_create_commit :audit_created
  before_destroy :audit_destroyed

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

  def latest_session_id
    pick_session(role_runs)
  end

  def latest_session_id_for(task)
    return latest_session_id if task.nil?

    own_session = pick_session(role_runs.where(task_id: task.id))
    return own_session if own_session
    return nil if task.root?

    root = task.root_ancestor
    sibling_ids = root.descendant_ids + [ root.id ] - [ task.id ]
    pick_session(role_runs.where(task_id: sibling_ids))
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

  def effective_working_directory
    ([ self ] + ancestors).find { |r| r.working_directory.present? }&.working_directory
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

  def inherit_parent_adapter
    return unless parent
    self.adapter_type ||= parent.adapter_type
    self.adapter_config = parent.adapter_config if adapter_config.blank? && parent.adapter_config.present?
  end

  def heartbeat_config_changed?
    saved_change_to_heartbeat_interval? || saved_change_to_heartbeat_enabled?
  end

  def sync_heartbeat_schedule
    Heartbeats::ScheduleManager.sync(self)
  end

  def reparent_children
    if parent_id.present? && !Role.exists?(parent_id)
      children.update_all(parent_id: nil)
    else
      children.update_all(parent_id: parent_id)
    end
  end

  def audit_created
    actor = audit_actor
    return unless actor

    record_audit_event!(actor: actor, action: "created", metadata: { title: title, category: role_category&.name })
  end
end
