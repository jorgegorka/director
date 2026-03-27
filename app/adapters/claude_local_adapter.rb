class ClaudeLocalAdapter < BaseAdapter
  def self.display_name
    "Claude Code (Local)"
  end

  def self.description
    "Run Claude CLI locally with streaming JSON output and session resumption"
  end

  def self.execute(agent, context)
    # Phase 7: Implement via Open3.popen3 with `claude` CLI, --output-format stream-json
    raise NotImplementedError, "Heartbeat execution comes in Phase 7"
  end

  def self.test_connection(agent)
    # Phase 7: Check `claude` CLI is installed and accessible
    raise NotImplementedError, "Connection testing comes in Phase 7"
  end
end
