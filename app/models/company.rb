class Company < ApplicationRecord
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :invitations, dependent: :destroy
  has_many :roles, dependent: :destroy
  has_many :agents, dependent: :destroy
  has_many :skills, dependent: :destroy
  has_many :tasks, dependent: :destroy
  has_many :goals, dependent: :destroy
  has_many :notifications, dependent: :destroy
  has_many :config_versions, dependent: :destroy
  has_many :audit_events, dependent: :delete_all

  after_create :seed_default_skills!

  validates :name, presence: true

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
