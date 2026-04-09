module Roles
  module AgentConfiguration
    extend ActiveSupport::Concern

    included do
      enum :adapter_type, { http: 0, process: 1, claude_local: 2, opencode: 3 }

      scope :agent_configured, -> { where.not(adapter_type: nil) }

      validates :adapter_type, presence: true, if: :agent_configured?
      validates :adapter_config, presence: true, if: :agent_configured?
      validate :validate_adapter_config_schema, if: :agent_configured?

      before_save :ensure_api_token, if: :agent_configured?
      after_save :assign_default_skills, if: :first_agent_configuration?
    end

    class_methods do
      def default_skill_keys_for(role_title)
        base = default_skills_config.fetch("_base", [])
        role_specific = default_skills_config.fetch(role_title.to_s.downcase.strip, [])
        (base + role_specific).uniq
      end

      def default_skills_config
        @default_skills_config ||= YAML.load_file(Rails.root.join("config/default_skills.yml"))
      end

      def generate_unique_api_token
        loop do
          token = SecureRandom.base58(24)
          break token unless exists?(api_token: token)
        end
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

    private

    def ensure_api_token
      self.api_token ||= self.class.generate_unique_api_token
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
      assign_skills_by_keys(self.class.default_skill_keys_for(title))
    end

    def assign_skills_by_keys(keys)
      return if keys.empty?

      existing_keys = skills.where(key: keys).pluck(:key)
      missing_keys = keys - existing_keys
      return if missing_keys.empty?

      project.skills.where(key: missing_keys).find_each do |skill|
        role_skills.find_or_create_by!(skill: skill)
      end

      skills.reset
    end
  end
end
