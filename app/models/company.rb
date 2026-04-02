class Company < ApplicationRecord
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :invitations, dependent: :destroy
  has_many :roles, dependent: :destroy
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

  def admin_recipients
    memberships
      .where(role: [ :owner, :admin ])
      .includes(:user)
      .map(&:user)
  end
end
