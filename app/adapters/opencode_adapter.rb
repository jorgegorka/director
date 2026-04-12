class OpencodeAdapter < BaseAdapter
  extend TmuxAdapterRunner

  SESSION_PREFIX = "director_opencode"

  def self.display_name
    "OpenCode"
  end

  def self.description
    "Run OpenCode CLI locally with JSON output"
  end

  def self.config_schema
    { required: %w[model], optional: %w[max_turns working_directory provider base_url] }
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

  OLLAMA_DEFAULT_BASE_URL = "http://localhost:11434/v1".freeze

  # Returns `-e KEY=value` flags for tmux new-session. When the role's
  # adapter_config has provider=ollama, OpenCode is pointed at the local
  # Ollama server via OPENAI_BASE_URL (Ollama exposes an OpenAI-compatible
  # API at /v1), avoiding any edit to the user's ~/.config/opencode/opencode.json.
  def self.env_flags(role)
    provider = role.adapter_config&.dig("provider").to_s
    provider == "ollama" ? ollama_env_flags(role) : default_env_flags
  end

  def self.default_env_flags
    forward_env_flags(FORWARDED_ENV_VARS).join(" ")
  end

  def self.ollama_env_flags(role)
    base_url = role.adapter_config&.dig("base_url").presence || OLLAMA_DEFAULT_BASE_URL

    flags = forward_env_flags(%w[HOME PATH])
    flags << "-e OPENAI_BASE_URL=#{base_url.shellescape}"
    flags << "-e OPENAI_API_KEY=ollama"
    flags.join(" ")
  end

  # Hook for TmuxAdapterRunner: returns the opencode CLI invocation string.
  def self.build_agent_command(role, context, temp_files)
    prompt_file = build_prompt_file(role, context, temp_files)
    mcp_config  = build_mcp_config(role, temp_files)
    build_opencode_command(role, prompt_file, mcp_config)
  end

  # Hook for TmuxAdapterRunner: parses opencode's json output.
  def self.parse_result(accumulated_lines)
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

  private_class_method def self.build_prompt_file(role, context, temp_files)
    prompt = role.compose_unified_prompt(context)

    file = Tempfile.new([ "opencode_prompt", ".txt" ])
    file.write(prompt)
    file.flush
    temp_files << file
    file
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
end
