require "shellwords"

class ClaudeLocalAdapter < BaseAdapter
  # Error raised when the agent's budget is exhausted before execution starts.
  # Caught by ExecuteAgentJob rescue StandardError clause.
  class BudgetExhausted < StandardError; end

  # Error raised when tmux session creation fails or times out.
  # Caught by ExecuteAgentJob rescue StandardError clause.
  class ExecutionError < StandardError; end

  POLL_INTERVAL  = 0.5   # seconds between capture-pane polls
  SESSION_PREFIX = "director_run"  # tmux session name prefix
  MAX_POLL_WAIT  = 300   # seconds, maximum time to poll before timeout (5 minutes)

  def self.display_name
    "Claude Code (Local)"
  end

  def self.description
    "Run Claude CLI locally with streaming JSON output and session resumption"
  end

  def self.config_schema
    { required: %w[model], optional: %w[max_turns session_id system_prompt allowed_tools] }
  end

  # Executes a claude CLI process in a tmux session and streams the JSON output
  # back into the AgentRun log. Returns a result hash with exit_code, session_id,
  # and cost_cents extracted from the stream-JSON result event.
  #
  # Raises BudgetExhausted (CLAUDE-06) before spawning if agent.budget_exhausted?.
  # Raises ExecutionError if tmux spawn fails or execution times out.
  def self.execute(agent, context)
    if agent.budget_exhausted?
      raise BudgetExhausted, "Agent budget exhausted: spent #{agent.monthly_spend_cents} of #{agent.budget_cents} cents budget"
    end

    agent_run    = AgentRun.find(context[:run_id])
    session_name = "#{SESSION_PREFIX}_#{context[:run_id]}"
    claude_cmd   = build_claude_command(agent, context)
    prefix       = env_prefix
    # -e sets an environment variable in the session; the last arg is the shell command to run.
    # claude_cmd already has its individual args shellescape-d, so just double-quote the whole string.
    spawn_cmd    = "tmux new-session -d -s #{session_name.shellescape} -e #{prefix} \"#{claude_cmd}\""

    unless spawn_session(spawn_cmd)
      raise ExecutionError, "Failed to create tmux session: #{session_name}"
    end

    accumulated_lines = poll_session(session_name, agent_run)
    parse_result(accumulated_lines)
  ensure
    cleanup_session(session_name) if defined?(session_name) && session_name
  end

  # ---------------------------------------------------------------------------
  # Overridable hooks -- public so define_singleton_method can shadow them in tests
  # without permanently removing the original method.
  # Same pattern as HttpAdapter.backoff_sleep.
  # ---------------------------------------------------------------------------

  # Overridable hook for poll sleep -- enables zero-sleep in tests.
  def self.poll_sleep(seconds)
    sleep(seconds)
  end

  # Builds the ANTHROPIC_API_KEY environment prefix for the tmux command.
  # Public so tests can override it to simulate missing API key.
  def self.env_prefix
    api_key = ENV.fetch("ANTHROPIC_API_KEY") { Rails.application.credentials.dig(:anthropic, :api_key) }
    raise ExecutionError, "ANTHROPIC_API_KEY not configured" if api_key.blank?
    "ANTHROPIC_API_KEY=#{api_key.shellescape}"
  end

  # Spawns a tmux session with the given command string. Returns true on success.
  def self.spawn_session(cmd)
    system(cmd)
  end

  # Returns true if the named tmux session currently exists.
  def self.session_exists?(name)
    system("tmux has-session -t #{name.shellescape} 2>/dev/null")
  end

  # Captures the current pane output of the named tmux session from scrollback start.
  def self.capture_pane(name)
    `tmux capture-pane -t #{name.shellescape} -p -S - 2>/dev/null`
  end

  # Kills the named tmux session, silently ignoring errors.
  def self.kill_session(name)
    system("tmux kill-session -t #{name.shellescape} 2>/dev/null")
  end

  private_class_method def self.build_claude_command(agent, context)
    config = agent.adapter_config
    prompt = context[:task_description] || context[:task_title] || "Execute assigned task"

    parts = [ "claude", "-p" ]
    parts << prompt.shellescape
    parts << "--output-format stream-json"
    parts << "--bare"  # CLAUDE-07: mandatory, prevents session file corruption
    parts << "--model #{config['model'].shellescape}" if config["model"].present?
    parts << "--max-turns #{config['max_turns'].to_i}" if config["max_turns"].present?
    parts << "--system-prompt #{config['system_prompt'].shellescape}" if config["system_prompt"].present?
    parts << "--allowedTools #{config['allowed_tools'].shellescape}" if config["allowed_tools"].present?
    parts << "--resume #{context[:resume_session_id].shellescape}" if context[:resume_session_id].present?  # CLAUDE-04
    parts.join(" ")
  end

  private_class_method def self.poll_session(session_name, agent_run)
    last_line_count = 0
    accumulated_lines = []
    poll_count = 0
    max_polls = (MAX_POLL_WAIT / POLL_INTERVAL).to_i

    loop do
      # Break if tmux session is gone (process exited naturally).
      break unless session_exists?(session_name)

      output = capture_pane(session_name)
      lines = output.split("\n")

      if lines.size > last_line_count
        new_lines = lines[last_line_count..]
        new_lines.each do |line|
          agent_run.broadcast_line!(line + "\n")
          accumulated_lines << line
        end
        last_line_count = lines.size
      end

      poll_sleep(POLL_INTERVAL)

      poll_count += 1
      if poll_count >= max_polls
        kill_session(session_name)
        raise ExecutionError, "Execution timed out after #{MAX_POLL_WAIT} seconds"
      end
    end

    # Final capture to collect any output produced after the last poll.
    output = capture_pane(session_name)
    lines = output.split("\n")
    if lines.size > last_line_count
      lines[last_line_count..].each do |line|
        agent_run.broadcast_line!(line + "\n")
        accumulated_lines << line
      end
    end

    accumulated_lines
  end

  private_class_method def self.parse_result(accumulated_lines)
    session_id = nil
    cost_cents = nil
    exit_code  = 0

    accumulated_lines.each do |line|
      next if line.blank?
      begin
        event = JSON.parse(line)
      rescue JSON::ParserError
        next
      end

      next unless event["type"] == "result"

      session_id = event["session_id"]  # CLAUDE-03
      if event["total_cost_usd"].present?
        cost_cents = (event["total_cost_usd"].to_f * 100).round  # CLAUDE-05
      end
      exit_code = 1 if event["subtype"] == "error"
    end

    { exit_code: exit_code, session_id: session_id, cost_cents: cost_cents }
  end

  private_class_method def self.cleanup_session(name)
    kill_session(name)
  end
end
