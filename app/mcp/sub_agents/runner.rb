require "open3"
require "shellwords"
require "tempfile"

module SubAgents
  # Spawns a short-lived `claude -p` subprocess for a sub-agent. Lives
  # entirely inside the parent MCP server process -- there is no tmux, no
  # resumable session, no adapter retry machinery. The subprocess inherits
  # Anthropic auth from the parent's environment (same ANTHROPIC_API_KEY /
  # CLAUDE_CODE_OAUTH_TOKEN that the orchestrator is already using), so we
  # never touch the Messages API directly.
  #
  # The subprocess is pointed at the SAME `bin/director-mcp` binary, but
  # with DIRECTOR_TOOL_SCOPE set to the sub-agent's scope -- so the nested
  # MCP server registers only the narrow tool subset the sub-agent needs,
  # preventing accidental recursion into the orchestrator's own sub-agent
  # wrappers.
  class Runner
    class ExecutionError < StandardError; end

    def run(sub_agent)
      invocation = nil
      started_at = nil

      if sub_agent.parent_role_run
        invocation = SubAgentInvocation.start!(
          role_run: sub_agent.parent_role_run,
          sub_agent_name: sub_agent.class.sub_agent_name,
          input_summary: sub_agent.build_input_summary
        )
      end

      started_at = monotonic_now
      temp_files = []

      command, env = build_command(sub_agent, temp_files)
      stdout, status = capture(command: command, env: env)
      lines = stdout.split("\n")

      result = ClaudeLocalAdapter.parse_result(lines)
      cost = result[:cost_cents].to_i
      duration_ms = ((monotonic_now - started_at) * 1000).round
      summary = extract_summary(lines) || result[:error_message] || "(no summary)"

      if status.success? && result[:exit_code].to_i.zero?
        invocation&.finish!(
          result_summary: summary,
          cost_cents: cost,
          duration_ms: duration_ms,
          iterations: 0
        )
        {
          status: "ok",
          sub_agent: sub_agent.class.sub_agent_name,
          cost_cents: cost,
          session_id: result[:session_id],
          summary: summary
        }
      else
        error = result[:error_message].presence || "claude CLI exited #{status.exitstatus}"
        invocation&.fail!(
          error_message: error,
          cost_cents: cost,
          duration_ms: duration_ms,
          iterations: 0
        )
        {
          status: "error",
          sub_agent: sub_agent.class.sub_agent_name,
          error: error,
          cost_cents: cost
        }
      end
    rescue StandardError => e
      if invocation
        invocation.fail!(
          error_message: e.message,
          cost_cents: 0,
          duration_ms: started_at ? ((monotonic_now - started_at) * 1000).round : nil,
          iterations: 0
        )
      end
      {
        status: "error",
        sub_agent: sub_agent.class.sub_agent_name,
        error: e.message
      }
    ensure
      temp_files&.each { |f| f.close! rescue nil }
    end

    # Spawns `/bin/sh -c <command>` with the given env vars and returns
    # `[stdout, status]`. Public (not private) so tests can stub it on a
    # Runner instance without needing to module-stub Open3.
    def capture(command:, env:)
      stdout, _stderr, status = Open3.capture3(env, "/bin/sh", "-c", command)
      [ stdout, status ]
    rescue StandardError => e
      raise ExecutionError, "Failed to spawn claude subprocess: #{e.message}"
    end

    private
      def build_command(sub_agent, temp_files)
        role = sub_agent.role

        system_prompt_file = write_tempfile("director_sub_sysprompt", ".txt", sub_agent.system_prompt)
        temp_files << system_prompt_file

        mcp_config_file = write_tempfile(
          "director_sub_mcp", ".json",
          build_mcp_config(role, sub_agent.class.tool_scope).to_json
        )
        temp_files << mcp_config_file

        parts = [ "claude", "-p" ]
        parts << sub_agent.user_message.shellescape
        parts.concat(ClaudeLocalAdapter::CLI_COMMON_FLAGS)
        parts << "--max-turns #{sub_agent.max_turns.to_i}"
        parts << "--system-prompt-file #{system_prompt_file.path.shellescape}"
        parts << "--mcp-config #{mcp_config_file.path.shellescape}"

        chosen_model = sub_agent.model || role.adapter_config&.dig("model")
        parts << "--model #{chosen_model.shellescape}" if chosen_model.present?

        # ANTHROPIC_API_KEY / CLAUDE_CODE_OAUTH_TOKEN are already in ENV for the
        # orchestrator's director-mcp process (tmux forwarded them), so Open3
        # carries them through to the sub-agent's claude CLI automatically.
        [ parts.join(" "), {} ]
      end

      def build_mcp_config(role, tool_scope)
        {
          mcpServers: {
            director: {
              command: Rails.root.join("bin", "director-mcp").to_s,
              env: {
                "DIRECTOR_API_TOKEN" => role.api_token,
                "DIRECTOR_TOOL_SCOPE" => tool_scope.to_s
              }
            }
          }
        }
      end

      # Stream-json output includes an `assistant` event for each message; the
      # last one carries the sub-agent's final text response, which we use as
      # the human-readable summary on the invocation record.
      def extract_summary(lines)
        last_text = nil
        lines.each do |line|
          next if line.blank?
          event = JSON.parse(line) rescue nil
          next unless event.is_a?(Hash)
          next unless event["type"] == "assistant"

          message = event.dig("message", "content") || event["content"]
          Array(message).each do |block|
            next unless block.is_a?(Hash) && block["type"] == "text"
            last_text = block["text"]
          end
        end
        last_text&.truncate(500)
      end

      def write_tempfile(prefix, suffix, content)
        file = Tempfile.new([ prefix, suffix ])
        file.write(content)
        file.flush
        file
      end

      def monotonic_now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
  end
end
