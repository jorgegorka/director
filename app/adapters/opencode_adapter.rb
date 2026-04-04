require "open3"
require "shellwords"
require "tempfile"

class OpencodeAdapter < BaseAdapter
  # Error raised when the agent's budget is exhausted before execution starts.
  class BudgetExhausted < StandardError; end

  # Error raised when tmux session creation fails or times out.
  class ExecutionError < StandardError; end

  POLL_INTERVAL  = 0.5
  SESSION_PREFIX = "director_opencode"
  MAX_POLL_WAIT  = 300
  STALL_TIMEOUT  = 60
  STALL_RETRIES  = 1

  def self.display_name
    "OpenCode"
  end

  def self.description
    "Run OpenCode CLI locally with JSON output"
  end

  def self.config_schema
    { required: %w[model], optional: %w[max_turns working_directory] }
  end

  # Executes an opencode CLI process in a tmux session and streams the JSON output
  # back into the RoleRun log. Returns a result hash with exit_code and cost_cents
  # extracted from the output if available.
  #
  # Retries once on transient errors (stalls) before giving up.
  # Raises BudgetExhausted before spawning if role.budget_exhausted?.
  # Raises ExecutionError if tmux spawn fails or execution times out.
  def self.execute(role, context)
    if role.budget_exhausted?
      raise BudgetExhausted, "Role budget exhausted: spent #{role.monthly_spend_cents} of #{role.budget_cents} cents budget"
    end

    retries_remaining = STALL_RETRIES
    begin
      execute_once(role, context)
    rescue ExecutionError => e
      if retries_remaining > 0 && retryable_error?(e)
        retries_remaining -= 1
        retry
      end
      raise
    end
  end

  private_class_method def self.execute_once(role, context)
    role_run     = RoleRun.find(context[:run_id])
    session_name = "#{SESSION_PREFIX}_#{context[:run_id]}"
    working_dir  = resolve_working_directory(role.effective_working_directory)
    temp_files   = []

    prompt_file = build_prompt_file(context, temp_files)
    mcp_config  = build_mcp_config(role, temp_files)
    cmd         = build_opencode_command(role, prompt_file, mcp_config)

    spawn_cmd = "tmux new-session -d -s #{session_name.shellescape}"
    spawn_cmd += " -c #{working_dir.shellescape}" if working_dir.present?
    spawn_cmd += " #{env_flags}" if env_flags.present?
    spawn_cmd += " #{cmd.shellescape}"
    spawn_cmd += " \\; set-option remain-on-exit on"

    kill_session(session_name)
    spawn_session(spawn_cmd)

    accumulated_lines = poll_session(session_name, role_run)
    parse_result(accumulated_lines)
  ensure
    cleanup_session(session_name) if defined?(session_name) && session_name
    temp_files&.each { |f| f.close! rescue nil }
  end

  private_class_method def self.retryable_error?(error)
    error.message.match?(/stalled|exited without producing a result/i)
  end

  # Overridable hook for poll sleep -- enables zero-sleep in tests.
  def self.poll_sleep(seconds)
    sleep(seconds)
  end

  # Environment variables to forward to the tmux session.
  # OpenCode supports various provider API keys via environment.
  FORWARDED_ENV_VARS = %w[
    HOME PATH
    ANTHROPIC_API_KEY OPENAI_API_KEY GEMINI_API_KEY
    GITHUB_TOKEN GROQ_API_KEY
    AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_REGION
    AZURE_OPENAI_ENDPOINT AZURE_OPENAI_API_KEY AZURE_OPENAI_API_VERSION
    VERTEXAI_PROJECT VERTEXAI_LOCATION LOCAL_ENDPOINT
  ].freeze

  def self.env_flags
    flags = FORWARDED_ENV_VARS.filter_map do |var|
      value = ENV[var]
      "-e #{var}=#{value.shellescape}" if value.present?
    end

    flags.join(" ")
  end

  # Spawns a tmux session with the given command string.
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

  # Returns true if the tmux pane is still alive (not dead).
  def self.pane_alive?(name)
    return false unless session_exists?(name)
    out, status = Open3.capture2("tmux", "display-message", "-t", name, "-p", '#{pane_dead}')
    return false unless status.success?
    out.strip == "0"
  end

  # Captures the current pane output of the named tmux session from scrollback start.
  def self.capture_pane(name)
    `tmux capture-pane -t #{name.shellescape} -p -S - 2>/dev/null`
  end

  # Kills the named tmux session, silently ignoring errors.
  def self.kill_session(name)
    system("tmux kill-session -t #{name.shellescape} 2>/dev/null")
  end

  private_class_method def self.build_prompt_file(context, temp_files)
    prompt = build_user_prompt(context)

    file = Tempfile.new([ "opencode_prompt", ".txt" ])
    file.write(prompt)
    file.flush
    temp_files << file
    file
  end

  private_class_method def self.build_user_prompt(context)
    if context[:trigger_type] == "task_pending_review" && context[:task_id].present?
      prompt = "Task ##{context[:task_id]} is pending your review"
      prompt += ": #{context[:task_title]}" if context[:task_title].present?
      prompt += "\n\n#{context[:assignee_role_title]} has submitted this task for review." if context[:assignee_role_title].present?
      prompt.strip
    elsif context[:task_id].present?
      prompt = "You have been assigned Task ##{context[:task_id]}"
      prompt += ": #{context[:task_title]}" if context[:task_title].present?
      prompt += "\n\n#{context[:task_description]}" if context[:task_description].present?
      prompt.strip
    elsif context[:goal_id].present?
      prompt = "You have been assigned Goal: #{context[:goal_title]}"
      prompt += "\n\n#{context[:goal_description]}" if context[:goal_description].present?

      if context[:goal_active_tasks].present?
        task_list = context[:goal_active_tasks].map { |t| "- Task ##{t[:id]}: #{t[:title]} (#{t[:status]})" }.join("\n")
        prompt += "\n\nActive Tasks:\n\n#{task_list}"
      end
      prompt.strip
    else
      "Check your assigned goals and tasks, then execute the highest-priority work."
    end
  end

  private_class_method def self.build_opencode_command(role, prompt_file, mcp_config)
    config = role.adapter_config

    parts = [ "opencode" ]
    parts << "-f json"
    parts << "-q"
    parts << "-p"
    parts << "$(cat #{prompt_file.path.shellescape})"

    # OpenCode uses --model flag for model selection
    parts << "--model #{config['model'].shellescape}" if config["model"].present?
    parts << "--max-turns #{config['max_turns'].to_i}" if config["max_turns"].present?
    parts << "--mcp-config #{mcp_config.path.shellescape}" if mcp_config

    parts.join(" ")
  end

  private_class_method def self.build_mcp_config(role, temp_files)
    return nil unless role.api_token.present?

    bin_path = Rails.root.join("bin", "director-mcp").to_s
    config = {
      mcpServers: {
        director: {
          type: "stdio",
          command: bin_path,
          env: { "DIRECTOR_API_TOKEN" => role.api_token }
        }
      }
    }

    file = Tempfile.new([ "opencode_mcp", ".json" ])
    file.write(config.to_json)
    file.flush
    temp_files << file
    file
  end

  private_class_method def self.poll_session(session_name, role_run)
    last_line_count = 0
    accumulated_lines = []
    poll_count = 0
    max_polls = (MAX_POLL_WAIT / POLL_INTERVAL).to_i
    last_new_output_at = Time.current

    loop do
      output = capture_pane(session_name)
      lines = output.split("\n")

      if lines.size > last_line_count
        last_new_output_at = Time.current
        new_lines = lines[last_line_count..]
        new_lines.each do |line|
          role_run.broadcast_line!(line + "\n")
          accumulated_lines << line
        end
        last_line_count = lines.size
      end

      break unless pane_alive?(session_name)

      stall_elapsed = Time.current - last_new_output_at
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
    cost_cents = nil
    exit_code = 0
    error_message = nil

    accumulated_lines.each do |line|
      next if line.blank?
      begin
        event = JSON.parse(line)
      rescue JSON::ParserError
        next
      end

      # Extract cost if present in the output
      if event["cost_usd"].present?
        cost_cents = (event["cost_usd"].to_f * 100).round
      elsif event["total_cost_usd"].present?
        cost_cents = (event["total_cost_usd"].to_f * 100).round
      elsif event["usage"].present? && event["usage"]["cost_usd"].present?
        cost_cents = (event["usage"]["cost_usd"].to_f * 100).round
      end

      # Check for error status
      if event["error"].present? || event["status"] == "error"
        exit_code = 1
        error_message = event["error"] || event["message"]
      end
    end

    { exit_code: exit_code, cost_cents: cost_cents, error_message: error_message }
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
