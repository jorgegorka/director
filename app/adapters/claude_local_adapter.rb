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

  # Shared flags for every `claude -p` subprocess Director spawns. The
  # --setting-sources / --disable-slash-commands pair drops the host's
  # ~/.claude/settings.json so host-enabled plugins can't inject SessionStart
  # hooks or the Skill tool into a Director agent.
  CLI_COMMON_FLAGS = [
    "--output-format stream-json --verbose",
    "--dangerously-skip-permissions",
    "--setting-sources project,local",
    "--disable-slash-commands"
  ].freeze

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
    prompt = role.build_user_prompt(context)

    parts = [ "claude", "-p" ]
    parts << prompt.shellescape
    parts.concat(CLI_COMMON_FLAGS)
    parts << "--model #{config['model'].shellescape}" if config["model"].present?
    parts << "--max-turns #{config['max_turns'].to_i}" if config["max_turns"].present?

    system_prompt = role.compose_system_prompt(context)
    if system_prompt.present?
      file = Tempfile.new([ "director_sysprompt", ".txt" ])
      file.write(system_prompt)
      file.flush
      temp_files << file
      parts << "--system-prompt-file #{file.path.shellescape}"
    end

    mcp_config = build_mcp_config(role, temp_files)
    parts << "--mcp-config #{mcp_config.path.shellescape}" if mcp_config

    allowed = config["allowed_tools"].presence || "mcp__director__*"
    parts << "--allowedTools #{allowed.shellescape}"
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
end
