class Company < ApplicationRecord
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :invitations, dependent: :destroy
  has_many :roles, dependent: :destroy
  has_many :role_categories, dependent: :destroy
  has_many :skills, dependent: :destroy
  has_many :tasks, dependent: :destroy
  has_many :goals, dependent: :destroy
  has_many :notifications, dependent: :destroy
  has_many :config_versions, dependent: :destroy
  has_many :documents, dependent: :destroy
  has_many :document_tags, dependent: :destroy
  has_many :goal_evaluations, dependent: :destroy
  has_many :role_runs
  has_many :audit_events, dependent: :delete_all

  after_create :seed_default_role_categories!
  after_create :seed_default_skills!

  validates :name, presence: true
  validates :max_concurrent_agents, numericality: { greater_than_or_equal_to: 0, only_integer: true }

  def concurrent_agent_limit_reached?
    return false if max_concurrent_agents.zero?
    role_runs.where(status: [ :queued, :running ]).count >= max_concurrent_agents
  end

  def dispatch_next_throttled_run!
    return if concurrent_agent_limit_reached?

    busy_role_ids = role_runs.where(status: [ :queued, :running ]).select(:role_id)
    next_run = role_runs.where(status: :throttled)
                        .where.not(role_id: busy_role_ids)
                        .order(:created_at)
                        .first
    return unless next_run

    next_run.update!(status: :queued)
    ExecuteRoleJob.perform_later(next_run.id)
  end

  def seed_default_role_categories!
    RoleCategory.default_definitions.each do |data|
      role_categories.find_or_create_by!(name: data.fetch("name")) do |cat|
        cat.description = data["description"]
        cat.job_spec = data.fetch("job_spec")
      end
    end
  end

  def seed_default_skills!
    self.class.default_skill_definitions.each do |data|
      skills.find_or_create_by!(key: data.fetch("key")) do |skill|
        skill.name = data.fetch("name")
        skill.description = data["description"]
        skill.markdown = data.fetch("markdown")
        skill.category = data["category"]
        skill.builtin = true
      end
    end
  end

  def self.default_skill_definitions
    @default_skill_definitions ||= Dir[Rails.root.join("db/seeds/skills/*.yml")].map { |file| YAML.load_file(file) }.freeze
  end

  def preload_monthly_spend(roles)
    period_start = Date.current.beginning_of_month.beginning_of_day
    spend_by_role = Task.where(assignee_id: roles.select(:id))
      .where.not(cost_cents: nil)
      .where(created_at: period_start..)
      .group(:assignee_id)
      .sum(:cost_cents)
    roles.each { |r| r.preloaded_monthly_spend_cents = spend_by_role[r.id] || 0 }
    spend_by_role.values.sum
  end

  def admin_recipients
    memberships
      .where(role: [ :owner, :admin ])
      .includes(:user)
      .map(&:user)
  end
end
