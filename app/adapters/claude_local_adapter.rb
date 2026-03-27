class ClaudeLocalAdapter < BaseAdapter
  def self.display_name
    "Claude Code (Local)"
  end

  def self.description
    "Run Claude CLI locally with streaming JSON output and session resumption"
  end

  def self.config_schema
    { required: %w[model], optional: %w[max_turns session_id system_prompt allowed_tools] }
  end
end
