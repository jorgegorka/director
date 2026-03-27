module Adapters
  class Registry
    ADAPTERS = {
      "http" => "Adapters::HttpAdapter",
      "process" => "Adapters::ProcessAdapter",
      "claude_local" => "Adapters::ClaudeLocalAdapter"
    }.freeze

    CONFIG_SCHEMAS = {
      "http" => {
        required: %w[url],
        optional: %w[method headers auth_token timeout]
      },
      "process" => {
        required: %w[command],
        optional: %w[working_directory env timeout]
      },
      "claude_local" => {
        required: %w[model],
        optional: %w[max_turns session_id system_prompt allowed_tools]
      }
    }.freeze

    def self.for(adapter_type)
      class_name = ADAPTERS[adapter_type.to_s]
      raise ArgumentError, "Unknown adapter type: #{adapter_type}" unless class_name
      class_name.constantize
    end

    def self.required_config_keys(adapter_type)
      schema = CONFIG_SCHEMAS[adapter_type.to_s]
      return [] unless schema
      schema[:required] || []
    end

    def self.optional_config_keys(adapter_type)
      schema = CONFIG_SCHEMAS[adapter_type.to_s]
      return [] unless schema
      schema[:optional] || []
    end

    def self.all_config_keys(adapter_type)
      required_config_keys(adapter_type) + optional_config_keys(adapter_type)
    end

    def self.adapter_types
      ADAPTERS.keys
    end
  end
end
