class ClaudeLocalAdapter < BaseAdapter
  extend TmuxAdapterRunner

  SESSION_PREFIX = "director_run"

  def self.display_name
    "Claude Code (Local)"
  end

  def self.description
    "Run Claude CLI locally with streaming JSON output and session resumption"
  end

  def self.config_schema
    { required: %w[model], optional: %w[max_turns session_id allowed_tools provider base_url] }
  end

  # Auth priority for Claude CLI in tmux sessions:
  #   1. ANTHROPIC_API_KEY — direct API billing, most reliable for automation
  #   2. CLAUDE_CODE_OAUTH_TOKEN — subscription-based auth (Max/Pro), works headless
  #   3. Keychain/credentials file — requires HOME+PATH, may fail in tmux on macOS
  #
  # Tmux sessions inherit the tmux server's environment, not the calling
  # process's, so we explicitly forward all relevant variables.
  FORWARDED_ENV_VARS = %w[HOME PATH ANTHROPIC_API_KEY CLAUDE_CODE_OAUTH_TOKEN].freeze

  OLLAMA_DEFAULT_BASE_URL = "http://localhost:11434".freeze

  # Returns `-e KEY=value` flags for tmux new-session, branching on provider:
  #
  #   - provider "anthropic" (default): forwards hosted API credentials from
  #     ENV or Rails credentials, plus an isolated CLAUDE_CONFIG_DIR.
  #   - provider "ollama": forwards ANTHROPIC_BASE_URL + ANTHROPIC_AUTH_TOKEN
  #     pointing at the local Ollama server, and explicitly blanks
  #     ANTHROPIC_API_KEY so the Claude CLI does not bypass the base URL.
  def self.env_flags(role)
    provider = role.adapter_config&.dig("provider").to_s
    provider == "ollama" ? ollama_env_flags(role) : anthropic_env_flags
  end

  def self.anthropic_env_flags
    flags = forward_env_flags(FORWARDED_ENV_VARS)

    # Fall back to Rails credentials for keys not in ENV
    { "ANTHROPIC_API_KEY" => %i[anthropic api_key],
      "CLAUDE_CODE_OAUTH_TOKEN" => %i[anthropic oauth_token] }.each do |var, path|
      next if ENV[var].present?
      value = Rails.application.credentials.dig(*path)
      flags << "-e #{var}=#{value.shellescape}" if value.present?
    end

    flags << "-e CLAUDE_CONFIG_DIR=#{agent_config_dir.shellescape}"
    flags.join(" ")
  end

  # Ollama exposes an Anthropic-compatible API. The Claude CLI routes through
  # it when ANTHROPIC_BASE_URL is set and ANTHROPIC_AUTH_TOKEN is present. We
  # must also blank ANTHROPIC_API_KEY — if it is set (via ENV, credentials, or
  # the user's shell), the CLI prefers it and ignores ANTHROPIC_BASE_URL.
  def self.ollama_env_flags(role)
    base_url = role.adapter_config&.dig("base_url").presence || OLLAMA_DEFAULT_BASE_URL

    flags = forward_env_flags(%w[HOME PATH])
    flags << "-e ANTHROPIC_BASE_URL=#{base_url.shellescape}"
    flags << "-e ANTHROPIC_AUTH_TOKEN=ollama"
    flags << "-e ANTHROPIC_API_KEY="
    flags << "-e CLAUDE_CONFIG_DIR=#{agent_config_dir.shellescape}"
    flags.join(" ")
  end

  def self.agent_config_dir
    dir = Rails.root.join("tmp", "claude_agent_config")
    FileUtils.mkdir_p(dir)
    dir.to_s
  end

  # Hook for TmuxAdapterRunner: returns the claude CLI invocation string.
  def self.build_agent_command(role, context, temp_files)
    build_claude_command(role, context, temp_files)
  end

  # Hook for TmuxAdapterRunner: parses claude's stream-json output.
  # Raises ExecutionError when no `result` event was seen (legitimate failure
  # mode for a crashed CLI; retryable via TmuxAdapterRunner.retryable_error?).
  def self.parse_result(accumulated_lines)
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

    if session_id.nil? && error_message.nil?
      raise ExecutionError, "Agent process exited without producing a result"
    end

    { exit_code: exit_code, session_id: session_id, cost_cents: cost_cents, error_message: error_message }
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

      You coordinate work through Director MCP tools. Three of them are **specialists** — when you call them, a focused sub-agent takes over that one decision on your behalf. You do not need to write task descriptions, review criteria, or hiring job specs inline; the specialist does that.

      Specialist tools (delegate reasoning to them):
      - **create_task** — give an intent, the specialist writes the task and picks an assignee
      - **review_task** — hand off a pending-review task, the specialist judges and approves/rejects
      - **hire_role** — give an intent, the specialist picks a template and budget
      - **summarize_goal** — call when a tool response includes a `goal_completed` hint; the specialist writes the achievement summary shown to the user

      Direct tools (you use these yourself):
      - **list_my_tasks** / **get_task_details** — inspect your work
      - **list_my_goals** / **get_goal_details** / **update_goal** — inspect and update goals
      - **list_available_roles** / **list_hirable_roles** — see who is on your team
      - **update_task_status** — mark your own assigned tasks in_progress or pending_review
      - **add_message** — comment on a task
      - **search_documents** / **get_document** — read from the company document library

      Your job is to decide *what* needs to happen and hand each decision to the right specialist. Do not try to reproduce their reasoning.

      ## Efficiency Rules

      - Do NOT call get_task_details if the task details are already in this prompt — start working immediately
      - Do NOT call update_task_status("in_progress") — tasks are auto-marked in_progress when your session starts
      - Prefer batching independent tool calls in parallel
      - When any tool response includes `goal_completed: { id, ... }`, call `summarize_goal` with that id before continuing. The user relies on this summary for feedback on finished goals.
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
      prompt += "\n\nHand this off to the review_task specialist -- do not read the task and decide yourself."
      prompt.strip
    elsif context[:task_id].present?
      prompt = "You have been assigned Task ##{context[:task_id]}"
      prompt += ": #{context[:task_title]}" if context[:task_title].present?
      prompt += "\n\n#{context[:task_description]}" if context[:task_description].present?
      prompt += "\n\nThe task is already marked in_progress. The details above are complete — start working immediately."
      prompt.strip
    elsif context[:goal_id].present?
      prompt = "You have been assigned Goal: **#{context[:goal_title]}**"
      prompt += "\n\n#{context[:goal_description]}" if context[:goal_description].present?

      if context[:goal_active_tasks].present?
        task_list = context[:goal_active_tasks].map { |t| "- Task ##{t[:id]}: #{t[:title]} (#{t[:status]})" }.join("\n")
        prompt += "\n\n## Active Tasks\n\n#{task_list}"
        prompt += "\n\nThis goal already has work in progress. Focus on completing the existing tasks above — do NOT create new tasks unless all current ones are completed or blocked and more work is clearly needed."
      else
        prompt += "\n\nThis is a new goal with no tasks yet. Decide the first piece of work and hand it to the create_task specialist -- do not write the task description yourself."
      end
      prompt.strip
    else
      "Check your assigned goals with list_my_goals and tasks with list_my_tasks, then execute the highest-priority work."
    end
  end
end
