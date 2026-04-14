class AdapterRegistry
  ADAPTERS = {
    "http" => HttpAdapter,
    "process" => ProcessAdapter,
    "claude_local" => ClaudeLocalAdapter,
    "opencode" => OpencodeAdapter,
    "codex" => CodexAdapter
  }.freeze

  def self.for(adapter_type)
    adapter = ADAPTERS[adapter_type.to_s]
    raise ArgumentError, "Unknown adapter type: #{adapter_type}" unless adapter
    adapter
  end

  def self.required_config_keys(adapter_type)
    self.for(adapter_type).config_schema[:required] || []
  end

  def self.optional_config_keys(adapter_type)
    self.for(adapter_type).config_schema[:optional] || []
  end

  def self.all_config_keys(adapter_type)
    required_config_keys(adapter_type) + optional_config_keys(adapter_type)
  end

  def self.adapter_types
    ADAPTERS.keys
  end
end
