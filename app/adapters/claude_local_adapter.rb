class ClaudeLocalAdapter < BaseAdapter
  def self.display_name
    "Claude Code (Local)"
  end

  def self.description
    "Run Claude CLI locally with streaming JSON output and session resumption"
  end
end
