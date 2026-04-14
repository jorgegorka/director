class CodexAdapter < BaseAdapter
  extend TmuxAdapterRunner

  SESSION_PREFIX = "director_codex"

  def self.display_name
    "OpenAI Codex (Local)"
  end

  def self.description
    "Run Codex CLI locally with JSON event stream and session resumption"
  end

  def self.config_schema
    { required: %w[model], optional: %w[max_turns provider base_url sandbox approval] }
  end

  # Auth priority for Codex CLI in tmux sessions:
  #   1. OPENAI_API_KEY / CODEX_API_KEY — direct API billing
  #   2. ChatGPT session via `codex login` is intentionally not supported here,
  #      since each role uses its own CODEX_HOME and would not see ~/.codex/auth.json.
  FORWARDED_ENV_VARS = %w[HOME PATH OPENAI_API_KEY CODEX_API_KEY].freeze

  OLLAMA_DEFAULT_BASE_URL = "http://localhost:11434/v1".freeze

  # Headless-safe defaults. workspace-write + ask-for-approval=never lets the
  # agent edit files in its working tree without prompting; users can override
  # `sandbox` / `approval` via adapter_config to tighten or loosen this.
  CLI_COMMON_FLAGS = [
    "--json",
    "--skip-git-repo-check",
    "--sandbox workspace-write",
    "--ask-for-approval never"
  ].freeze

  # Returns `-e KEY=value` flags for tmux new-session, branching on provider:
  #
  #   - default: forward OpenAI/Codex API keys from ENV or Rails credentials.
  #   - "ollama": point Codex at the local Ollama server via OPENAI_BASE_URL
  #     (Ollama exposes an OpenAI-compatible API at /v1) and blank out real keys.
  #
  # CODEX_HOME is set to a per-role directory so we can drop a config.toml
  # with our MCP server entry without touching the user's ~/.codex/.
  def self.env_flags(role)
    provider = role.adapter_config&.dig("provider").to_s
    flags = provider == "ollama" ? ollama_env_flags(role) : openai_env_flags
    flags << "-e CODEX_HOME=#{agent_codex_home(role).shellescape}"
    flags.join(" ")
  end

  def self.openai_env_flags
    flags = forward_env_flags(FORWARDED_ENV_VARS)

    { "OPENAI_API_KEY" => %i[openai api_key],
      "CODEX_API_KEY"  => %i[openai codex_api_key] }.each do |var, path|
      next if ENV[var].present?
      value = Rails.application.credentials.dig(*path)
      flags << "-e #{var}=#{value.shellescape}" if value.present?
    end

    flags
  end

  def self.ollama_env_flags(role)
    base_url = role.adapter_config&.dig("base_url").presence || OLLAMA_DEFAULT_BASE_URL

    flags = forward_env_flags(%w[HOME PATH])
    flags << "-e OPENAI_BASE_URL=#{base_url.shellescape}"
    flags << "-e OPENAI_API_KEY=ollama"
    flags << "-e CODEX_API_KEY="
    flags
  end

  def self.agent_codex_home(role)
    dir = Rails.root.join("tmp", "codex_agent_config", role.id.to_s)
    FileUtils.mkdir_p(dir)
    dir.to_s
  end

  # Hook for TmuxAdapterRunner: returns the codex CLI invocation string.
  def self.build_agent_command(role, context, temp_files)
    write_mcp_config!(role)
    prompt_file = build_prompt_file(role, context, temp_files)
    build_codex_command(role, context, prompt_file)
  end

  # Hook for TmuxAdapterRunner: parses codex's --json (newline-delimited)
  # output. The exact event schema is not fully documented, so the parser
  # probes several plausible key paths and tightens once a real run pins them.
  def self.parse_result(accumulated_lines)
    session_id = nil
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

      session_id ||= event["session_id"] ||
                     event.dig("msg", "session_id") ||
                     event.dig("session", "id")

      cost = event["total_cost_usd"] ||
             event.dig("usage", "total_cost_usd") ||
             event.dig("usage", "cost_usd") ||
             event["cost_usd"]
      cost_cents = (cost.to_f * 100).round if cost.present?

      if event["type"].to_s.include?("error") || event["error"].present?
        exit_code = 1
        err = event["error"]
        error_message = (err.is_a?(Hash) ? err["message"] : err) || event["message"]
      end
    end

    if session_id.nil? && error_message.nil?
      raise ExecutionError, "Codex exited without producing a result"
    end

    { exit_code: exit_code, session_id: session_id, cost_cents: cost_cents, error_message: error_message }
  end

  private_class_method def self.build_prompt_file(role, context, temp_files)
    prompt = role.compose_unified_prompt(context)

    file = Tempfile.new([ "codex_prompt", ".txt" ])
    file.write(prompt)
    file.flush
    temp_files << file
    file
  end

  private_class_method def self.build_codex_command(role, context, prompt_file)
    config = role.adapter_config

    parts = [ "codex", "exec" ]
    parts << "resume #{context[:resume_session_id].shellescape}" if context[:resume_session_id].present?
    parts.concat(CLI_COMMON_FLAGS)
    parts << "--model #{config['model'].shellescape}" if config["model"].present?
    parts << "--sandbox #{config['sandbox'].shellescape}" if config["sandbox"].present?
    parts << "--ask-for-approval #{config['approval'].shellescape}" if config["approval"].present?
    parts << "-"

    "cat #{prompt_file.path.shellescape} | " + parts.join(" ")
  end

  # Writes config.toml inside the per-role CODEX_HOME so Codex auto-loads it.
  # Inline `-c key=value` overrides would expose DIRECTOR_API_TOKEN via ps(1);
  # config.toml on disk avoids that leak.
  private_class_method def self.write_mcp_config!(role)
    return unless role.api_token.present?

    bin_path = Rails.root.join("bin", "director-mcp").to_s
    toml = <<~TOML
      [mcp_servers.director]
      command = #{bin_path.inspect}

      [mcp_servers.director.env]
      DIRECTOR_API_TOKEN = #{role.api_token.inspect}
    TOML

    File.write(File.join(agent_codex_home(role), "config.toml"), toml)
  end
end
