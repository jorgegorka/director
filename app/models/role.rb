class Role < ApplicationRecord
  include Tenantable
  include TreeHierarchy
  include ConfigVersioned

  belongs_to :agent, optional: true

  delegate :name, to: :agent, prefix: true, allow_nil: true

  def self.default_skill_keys_for(role_title)
    default_skills_config.fetch(role_title.to_s.downcase.strip, [])
  end

  def self.default_skills_config
    @default_skills_config ||= YAML.load_file(Rails.root.join("config/default_skills.yml"))
  end

  validates :title, presence: true,
                    uniqueness: { scope: :company_id, message: "already exists in this company" }

  before_destroy :reparent_children
  after_save :assign_default_skills_to_agent, if: :first_agent_assignment?

  def governance_attributes
    %w[title description job_spec parent_id agent_id]
  end

  private

  def first_agent_assignment?
    saved_change_to_agent_id? && agent_id.present? && agent_id_before_last_save.nil?
  end

  def assign_default_skills_to_agent
    skill_keys = self.class.default_skill_keys_for(title)
    return if skill_keys.empty?

    agent = Agent.find(agent_id)
    company_skills = agent.company.skills.where(key: skill_keys)
    existing_skill_ids = agent.agent_skills.where(skill: company_skills).pluck(:skill_id)

    company_skills.each do |skill|
      next if existing_skill_ids.include?(skill.id)
      agent.agent_skills.create!(skill: skill)
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
