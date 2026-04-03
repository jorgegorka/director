require "open3"
require "shellwords"
require "tempfile"

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
  STALL_TIMEOUT  = 120   # seconds without new output before declaring stall

  def self.display_name
    "Claude Code (Local)"
  end

  def self.description
    "Run Claude CLI locally with streaming JSON output and session resumption"
  end

  def self.config_schema
    { required: %w[model], optional: %w[max_turns session_id allowed_tools] }
  end

  # Executes a claude CLI process in a tmux session and streams the JSON output
  # back into the RoleRun log. Returns a result hash with exit_code, session_id,
  # and cost_cents extracted from the stream-JSON result event.
  #
  # Raises BudgetExhausted (CLAUDE-06) before spawning if role.budget_exhausted?.
  # Raises ExecutionError if tmux spawn fails or execution times out.
  def self.execute(role, context)
    if role.budget_exhausted?
      raise BudgetExhausted, "Role budget exhausted: spent #{role.monthly_spend_cents} of #{role.budget_cents} cents budget"
    end

    role_run     = RoleRun.find(context[:run_id])
    session_name = "#{SESSION_PREFIX}_#{context[:run_id]}"
    working_dir  = resolve_working_directory(role.working_directory)
    temp_files   = []
    claude_cmd   = build_claude_command(role, context, temp_files)
    env          = env_flags
    # -e sets environment variables in the session; the last arg is the shell command to run.
    # claude_cmd already has its individual args shellescape-d, so just double-quote the whole string.
    # remain-on-exit keeps the tmux pane alive after the command exits,
    # so we can always capture output even if Claude finishes quickly.
    spawn_cmd    = "tmux new-session -d -s #{session_name.shellescape}"
    spawn_cmd   += " -c #{working_dir.shellescape}" if working_dir.present?
    spawn_cmd   += " #{env}" if env.present?
    spawn_cmd   += " \"#{claude_cmd}\""
    spawn_cmd   += " \\; set-option remain-on-exit on"

    kill_session(session_name)
    spawn_session(spawn_cmd)

    accumulated_lines = poll_session(session_name, role_run)
    parse_result(accumulated_lines)
  ensure
    cleanup_session(session_name) if defined?(session_name) && session_name
    temp_files&.each { |f| f.close! rescue nil }
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

  # Auth priority for Claude CLI in tmux sessions:
  #   1. ANTHROPIC_API_KEY — direct API billing, most reliable for automation
  #   2. CLAUDE_CODE_OAUTH_TOKEN — subscription-based auth (Max/Pro), works headless
  #   3. Keychain/credentials file — requires HOME+PATH, may fail in tmux on macOS
  #
  # Tmux sessions inherit the tmux server's environment, not the calling
  # process's, so we explicitly forward all relevant variables.
  # Public so tests can override it.
  FORWARDED_ENV_VARS = %w[HOME PATH ANTHROPIC_API_KEY CLAUDE_CODE_OAUTH_TOKEN].freeze

  def self.env_flags
    flags = FORWARDED_ENV_VARS.filter_map do |var|
      value = ENV[var]
      "-e #{var}=#{value.shellescape}" if value.present?
    end

    # Fall back to Rails credentials for keys not in ENV
    { "ANTHROPIC_API_KEY" => %i[anthropic api_key],
      "CLAUDE_CODE_OAUTH_TOKEN" => %i[anthropic oauth_token] }.each do |var, path|
      next if ENV[var].present?
      value = Rails.application.credentials.dig(*path)
      flags << "-e #{var}=#{value.shellescape}" if value.present?
    end

    # Isolate agent sessions from user's personal Claude Code config.
    # Without this, agents inherit hooks, plugins, and MCP servers from ~/.claude/,
    # which bloats the system prompt and injects conflicting behavioral instructions.
    flags << "-e CLAUDE_CONFIG_DIR=#{agent_config_dir.shellescape}"

    flags.join(" ")
  end

  def self.agent_config_dir
    dir = Rails.root.join("tmp", "claude_agent_config")
    FileUtils.mkdir_p(dir)
    dir.to_s
  end

  # Spawns a tmux session with the given command string.
  # Returns stdout on success, raises ExecutionError with stderr on failure.
  def self.spawn_session(cmd)
    stdout, stderr, status = Open3.capture3(cmd)
    unless status.success?
      raise ExecutionError, "tmux spawn failed: #{stderr.strip.presence || "unknown error (exit #{status.exitstatus})"}"
    end
    stdout
  end

  # Returns true if the named tmux session currently exists.
  def self.session_exists?(name)
    system("tmux has-session -t #{name.shellescape} 2>/dev/null")
  end

  # Returns true if the process inside the tmux pane is still running.
  # With remain-on-exit, the session stays alive after exit — check pane_dead.
  def self.pane_alive?(name)
    return false unless session_exists?(name)
    result = `tmux display-message -t #{name.shellescape} -p '#\{pane_dead\}' 2>/dev/null`.strip
    result != "1"
  end

  # Captures the current pane output of the named tmux session from scrollback start.
  def self.capture_pane(name)
    `tmux capture-pane -t #{name.shellescape} -p -S - 2>/dev/null`
  end

  # Kills the named tmux session, silently ignoring errors.
  def self.kill_session(name)
    system("tmux kill-session -t #{name.shellescape} 2>/dev/null")
  end

  private_class_method def self.build_claude_command(role, context, temp_files)
    config = role.adapter_config
    prompt = build_user_prompt(context)

    parts = [ "claude", "-p" ]
    parts << prompt.shellescape
    parts << "--output-format stream-json --verbose"
    parts << "--dangerously-skip-permissions"
    parts << "--model #{config['model'].shellescape}" if config["model"].present?
    parts << "--max-turns #{config['max_turns'].to_i}" if config["max_turns"].present?

    system_prompt = compose_system_prompt(role, context)
    if system_prompt.present?
      file = Tempfile.new([ "director_sysprompt", ".txt" ])
      file.write(system_prompt)
      file.flush
      temp_files << file
      parts << "--system-prompt-file #{file.path.shellescape}"
    end

    mcp_config = build_mcp_config(role, temp_files)
    parts << "--mcp-config #{mcp_config.path.shellescape}" if mcp_config

    parts << "--allowedTools #{config['allowed_tools'].shellescape}" if config["allowed_tools"].present?
    parts << "--resume #{context[:resume_session_id].shellescape}" if context[:resume_session_id].present?  # CLAUDE-04
    parts.join(" ")
  end

  private_class_method def self.build_mcp_config(role, temp_files)
    return nil unless role.api_token.present?

    bin_path = Rails.root.join("bin", "director-mcp").to_s
    config = {
      mcpServers: {
        director: {
          command: bin_path,
          env: { "DIRECTOR_API_TOKEN" => role.api_token }
        }
      }
    }

    file = Tempfile.new([ "director_mcp", ".json" ])
    file.write(config.to_json)
    file.flush
    temp_files << file
    file
  end

  private_class_method def self.compose_system_prompt(role, context)
    parts = []

    parts << build_identity_prompt(role)
    parts << role.job_spec if role.job_spec.present?
    parts << role.role_category.job_spec if role.role_category&.job_spec.present?

    if context[:goal_title].present?
      parts << build_goal_prompt(context)
    end

    if context[:skills].present?
      parts << build_skills_prompt(context[:skills])
    end

    parts.join("\n\n")
  end

  private_class_method def self.build_identity_prompt(role)
    company_name = role.company&.name || "Unknown Company"
    manager = role.parent
    children = role.children.active.order(:title)

    manager_line = manager ? manager.title : "None (top-level role)"
    reports_line = if children.any?
      children.map(&:title).join(", ")
    else
      "None yet — you can hire subordinates using the hire_role tool"
    end

    <<~PROMPT.strip
      ## Your Identity

      You are **#{role.title}** at **#{company_name}**.
      #{role.description.present? ? "\n#{role.description}\n" : ""}
      ## Your Organization

      Manager: #{manager_line}
      Direct reports: #{reports_line}

      ## How to Work

      You have access to Director MCP tools for managing your organization:
      - **list_my_tasks** / **get_task_details** — see your current work
      - **create_task** — create tasks and assign them to your direct reports
      - **update_task_status** — mark tasks as in_progress or completed
      - **list_available_roles** — see who you can delegate to
      - **hire_role** / **list_hirable_roles** — hire new subordinate roles
      - **list_my_goals** / **get_goal_details** / **update_goal** — see, inspect, and update goals
      - **add_message** — communicate on tasks
      - **search_documents** — search the company document library by title or tag
      - **get_document** — fetch the full content of a document

      Use these Director MCP tools to accomplish your goals. Break goals into tasks, delegate to your reports, and track progress.
    PROMPT
  end

  private_class_method def self.build_goal_prompt(context)
    prompt = "## Current Goal\n\n**#{context[:goal_title]}**"
    prompt += "\n\n#{context[:goal_description]}" if context[:goal_description].present?
    prompt += <<~FOCUS

      ## Focus Rules

      Everything you do in this session must directly advance the goal above.
      - Do NOT create new goals — break work into tasks instead.
      - Do NOT start work outside this goal's scope.
      - If you spot a related opportunity or risk, use `add_message` to flag it — do not act on it.
    FOCUS
    prompt.strip
  end

  private_class_method def self.build_skills_prompt(skills)
    catalog = skills.map { |s| "- **#{s[:name]}** (#{s[:key]}): #{s[:description]}" }.join("\n")
    details = skills.map { |s| "<skill key=\"#{s[:key]}\">\n#{s[:markdown]}\n</skill>" }.join("\n\n")

    <<~PROMPT.strip
      ## Your Skills

      You have the following skills. Before starting work, identify which skill is most relevant to the current task and follow its instructions.

      #{catalog}

      ### Skill Instructions

      #{details}
    PROMPT
  end

  private_class_method def self.build_user_prompt(context)
    if context[:trigger_type] == "task_pending_review" && context[:task_id].present?
      prompt = "Task ##{context[:task_id]} is pending your review"
      prompt += ": #{context[:task_title]}" if context[:task_title].present?
      prompt += "\n\n#{context[:assignee_role_title]} has submitted this task for review." if context[:assignee_role_title].present?
      prompt += "\n\nUse `get_task_details` to read the submitted work and messages, then either approve with `update_task_status(task_id: #{context[:task_id]}, status: \"completed\")` or reject with `update_task_status(task_id: #{context[:task_id]}, status: \"open\", feedback: \"...\")`.".strip
    elsif context[:task_id].present?
      prompt = "You have been assigned Task ##{context[:task_id]}"
      prompt += ": #{context[:task_title]}" if context[:task_title].present?
      prompt += "\n\n#{context[:task_description]}" if context[:task_description].present?
      prompt.strip
    elsif context[:goal_id].present?
      prompt = "You have been assigned Goal: **#{context[:goal_title]}**"
      prompt += "\n\n#{context[:goal_description]}" if context[:goal_description].present?
      prompt += "\n\nCheck your tasks with `list_my_tasks` and goals with `list_my_goals`, then execute the highest-priority work."
      prompt.strip
    else
      "Check your assigned goals with list_my_goals and tasks with list_my_tasks, then execute the highest-priority work."
    end
  end

  private_class_method def self.poll_session(session_name, role_run)
    last_line_count = 0
    accumulated_lines = []
    poll_count = 0
    max_polls = (MAX_POLL_WAIT / POLL_INTERVAL).to_i
    last_new_output_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    loop do
      output = capture_pane(session_name)
      lines = output.split("\n")

      if lines.size > last_line_count
        last_new_output_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        new_lines = lines[last_line_count..]
        new_lines.each do |line|
          role_run.broadcast_line!(line + "\n")
          accumulated_lines << line
        end
        last_line_count = lines.size
      end

      # With remain-on-exit the session stays alive after the process exits,
      # so we check pane_dead instead of session_exists. This guarantees we
      # capture all output before breaking.
      break unless pane_alive?(session_name)

      stall_elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - last_new_output_at
      if stall_elapsed >= STALL_TIMEOUT
        kill_session(session_name)
        raise ExecutionError, "Agent stalled: no output for #{STALL_TIMEOUT} seconds"
      end

      poll_sleep(POLL_INTERVAL)

      poll_count += 1
      if poll_count >= max_polls
        kill_session(session_name)
        raise ExecutionError, "Execution timed out after #{MAX_POLL_WAIT} seconds"
      end
    end

    accumulated_lines
  end

  private_class_method def self.parse_result(accumulated_lines)
    session_id = nil
    cost_cents = nil
    exit_code  = 0
    error_message = nil

    accumulated_lines.each do |line|
      next if line.blank?
      begin
        event = JSON.parse(line)
      rescue JSON::ParserError
        next
      end

      # Detect authentication failures from assistant messages
      if event["type"] == "assistant" && event["error"] == "authentication_failed"
        raise ExecutionError, "Claude CLI not authenticated. Run `claude /login` to sign in."
      end

      next unless event["type"] == "result"

      session_id = event["session_id"]  # CLAUDE-03
      if event["total_cost_usd"].present?
        cost_cents = (event["total_cost_usd"].to_f * 100).round  # CLAUDE-05
      end
      if event["subtype"] == "error" || event["is_error"] == true
        exit_code = 1
        error_message = event["result"]
      end
    end

    { exit_code: exit_code, session_id: session_id, cost_cents: cost_cents, error_message: error_message }
  end

  private_class_method def self.resolve_working_directory(path)
    return nil if path.blank?

    resolved = File.realpath(path)
    unless File.directory?(resolved)
      raise ExecutionError, "Working directory is not a directory: #{path} (resolved to #{resolved})"
    end
    resolved
  rescue Errno::ENOENT
    raise ExecutionError, "Working directory does not exist: #{path}"
  end

  private_class_method def self.cleanup_session(name)
    kill_session(name)
  end
end
