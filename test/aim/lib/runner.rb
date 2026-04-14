require "open3"
require "shellwords"
require "tempfile"

module AIM
  class Runner
    Result = Struct.new(:scenario_id, :status, :role_title, :category, :message,
                        :tool_calls, :response, :cost_cents,
                        :duration_seconds, :error, :verdict, :assertion_failures,
                        :tool_errors, :first_tool_error,
                        keyword_init: true)

    ToolCallCapture = Struct.new(:tool, :params, :tool_use_id, :is_error, :error_text, keyword_init: true)

    DEFAULT_MAX_TURNS = 75

    def initialize(scenarios)
      @scenarios = scenarios
    end

    def execute
      @scenarios.map do |scenario|
        execute_scenario(scenario)
      end
    end

    private

      def execute_scenario(scenario)
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        temp_files = []
        tool_calls_captured = []

        role = find_role(scenario)
        context = build_context(scenario, role)

        # Clean up pollution from previous scenarios: any subtasks that a
        # prior run created under this task make the orchestrator see
        # "active subtasks" in its user prompt and correctly decide NOT to
        # delegate. Destroying subtasks resets the task to a freshly
        # assigned state each run.
        if context[:task_id]
          target = role.project.tasks.find_by(id: context[:task_id])
          if target
            target.subtasks.find_each(&:destroy)
            target.reload
            if target.root? && target.subtasks.empty?
              context.delete(:active_subtasks)
            end
          end
        end

        system_prompt = role.compose_system_prompt(context)
        user_prompt = role.build_user_prompt(context)

        # Write system prompt to tempfile
        sys_file = write_tempfile("aim_sysprompt", ".txt", system_prompt)
        temp_files << sys_file

        # Build MCP config
        mcp_file = write_tempfile("aim_mcp", ".json", build_mcp_config(role).to_json)
        temp_files << mcp_file

        # Build command
        model = role.adapter_config&.dig("model") || "claude-sonnet-4-20250514"
        max_turns = scenario[:max_turns] || DEFAULT_MAX_TURNS

        parts = [ "claude", "-p" ]
        parts << user_prompt.shellescape
        parts.concat(ClaudeLocalAdapter::CLI_COMMON_FLAGS)
        parts << "--model #{model.shellescape}"
        parts << "--max-turns #{max_turns}"
        parts << "--system-prompt-file #{sys_file.path.shellescape}"
        parts << "--mcp-config #{mcp_file.path.shellescape}"
        parts << "--allowedTools mcp__director__*"

        command = parts.join(" ")

        # Execute
        stdout, _stderr, _status = Open3.capture3(command)
        lines = stdout.split("\n")

        # Parse tool calls from stream-json
        tool_calls_captured = extract_tool_calls(lines)

        # Parse response text (last assistant message)
        response_text = extract_response(lines)

        # Parse result metadata (cost, session_id)
        result_meta = ClaudeLocalAdapter.parse_result(lines) rescue {}

        duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

        failures = evaluate_assertions(scenario, tool_calls_captured)
        verdict = failures.empty? ? "pass" : "fail"
        errored = tool_calls_captured.select { |c| c.is_error }
        first_error = errored.first

        Result.new(
          scenario_id: scenario[:id],
          status: "success",
          role_title: role.title,
          category: role.role_category.name,
          message: user_prompt,
          tool_calls: tool_calls_captured,
          response: response_text,
          cost_cents: result_meta[:cost_cents],
          duration_seconds: duration.round(2),
          verdict: verdict,
          assertion_failures: failures,
          tool_errors: errored.size,
          first_tool_error: first_error && { tool: first_error.tool, error: first_error.error_text }
        )
      rescue => e
        duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
        Result.new(
          scenario_id: scenario[:id],
          status: "error",
          role_title: scenario[:role_title],
          category: scenario[:category],
          message: nil,
          tool_calls: tool_calls_captured || [],
          response: nil,
          cost_cents: 0,
          duration_seconds: duration.round(2),
          error: "#{e.class}: #{e.message}",
          verdict: "error",
          assertion_failures: []
        )
      ensure
        temp_files&.each { |f| f.close! rescue nil }
      end

      def find_role(scenario)
        project = Project.find_by!(name: "AIM Test Project")
        Current.project = project
        project.roles.find_by!(title: scenario[:role_title])
      end

      # Mirrors ExecuteRoleJob#build_context so test prompts match production:
      # a root task populates active_subtasks, a subtask populates root_task_*.
      def build_context(scenario, role)
        ctx = { trigger_type: scenario[:trigger_type] }
        sc = scenario[:context] || {}
        ctx[:human_feedback] = sc[:human_feedback] if sc[:human_feedback].present?

        if sc[:task_title]
          task = resolve_task(role, sc)
          if task
            ctx[:task_id] = task.id
            ctx[:task_title] = task.title
            ctx[:task_description] = sc[:task_description].presence || task.description
            ctx[:assignee_role_title] = task.assignee&.title

            if task.root?
              active = task.subtasks.active.order(priority: :desc, created_at: :desc)
              if active.any?
                ctx[:active_subtasks] = active.map { |t|
                  { id: t.id, title: t.title, status: t.status, assignee_id: t.assignee_id }
                }
              end
            else
              root = task.root_ancestor
              ctx[:root_task_id] = root.id
              ctx[:root_task_title] = root.title
              ctx[:root_task_description] = root.description
            end
          else
            ctx[:task_id] = sc[:task_id] || 999
            ctx[:task_title] = sc[:task_title]
            ctx[:task_description] = sc[:task_description]
            ctx[:assignee_role_title] = sc[:assignee_role_title]
          end
        end

        skills = role.skills.includes(:documents).to_a
        ctx[:skills] = skills.map do |skill|
          hash = {
            key: skill.key, name: skill.name,
            description: skill.description, category: skill.category,
            markdown: skill.markdown
          }
          linked = skill.documents.map { |d| { id: d.id, title: d.title } }
          hash[:linked_documents] = linked if linked.any?
          hash
        end

        ctx
      end

      def resolve_task(role, sc)
        return nil unless sc[:task_title]
        role.project.tasks.find_by("title LIKE ?", "%#{sc[:task_title]}%")
      end

      def build_mcp_config(role)
        {
          mcpServers: {
            director: {
              command: Rails.root.join("bin", "director-mcp").to_s,
              env: { "DIRECTOR_API_TOKEN" => role.api_token }
            }
          }
        }
      end

      # Extract tool_use blocks from assistant events AND correlate them with
      # their tool_result blocks from user events. The MCP layer surfaces
      # failures via `is_error: true` on the tool_result; without correlating
      # we'd mark a scenario PASS just because the tool name appeared, even
      # when the MCP call came back "Connection closed" or similar.
      def extract_tool_calls(lines)
        calls = []
        by_id = {}

        lines.each do |line|
          next if line.blank?
          event = JSON.parse(line) rescue next

          case event["type"]
          when "assistant"
            content = event.dig("message", "content") || event["content"]
            Array(content).each do |block|
              next unless block.is_a?(Hash) && block["type"] == "tool_use"
              capture = ToolCallCapture.new(
                tool: block["name"],
                params: block["input"],
                tool_use_id: block["id"],
                is_error: nil,
                error_text: nil
              )
              calls << capture
              by_id[block["id"]] = capture if block["id"]
            end
          when "user"
            content = event.dig("message", "content") || event["content"]
            Array(content).each do |block|
              next unless block.is_a?(Hash) && block["type"] == "tool_result"
              capture = by_id[block["tool_use_id"]]
              next unless capture
              capture.is_error = block["is_error"] == true
              if capture.is_error
                first = Array(block["content"]).first
                capture.error_text = (first.is_a?(Hash) ? first["text"] : first) || block["content"].to_s
              end
            end
          end
        end

        calls
      end

      # Extract the final assistant text response from stream-json output.
      def extract_response(lines)
        last_text = nil
        lines.each do |line|
          next if line.blank?
          event = JSON.parse(line) rescue next
          next unless event["type"] == "assistant"

          content = event.dig("message", "content") || event["content"]
          Array(content).each do |block|
            next unless block.is_a?(Hash) && block["type"] == "text"
            last_text = block["text"]
          end
        end
        last_text
      end

      # Checks expected_tools, forbidden_tools, and custom assertions against
      # the captured tool_calls. Returns an array of failure strings (empty =
      # pass). The rake task treats a failing scenario as "fail" in its
      # summary.
      def evaluate_assertions(scenario, tool_calls)
        failures = []
        # Successful (or ack'd non-error) calls satisfy `expected_tools` and
        # `allow_either` assertions -- a tool call whose MCP response was
        # `is_error: true` (e.g. "Connection closed") must not count as the
        # tool having been invoked. Forbidden-tool assertions count every
        # attempt regardless of error, because a forbidden call that failed
        # still indicates the LLM tried it.
        successful_names = tool_calls.reject { |tc| tc.is_error }.map { |tc| normalize_tool_name(tc.tool) }
        all_names = tool_calls.map { |tc| normalize_tool_name(tc.tool) }

        Array(scenario[:expected_tools]).each do |tool|
          target = normalize_tool_name(tool)
          unless successful_names.include?(target)
            failures << "expected tool not called (or only errored): #{tool}"
          end
        end

        Array(scenario[:forbidden_tools]).each do |tool|
          target = normalize_tool_name(tool)
          if all_names.include?(target)
            failures << "forbidden tool called: #{tool}"
          end
        end

        assertions = scenario[:assertions] || {}
        if (max = assertions[:search_documents_max_calls])
          count = all_names.count { |n| n == "search_documents" }
          if count > max
            failures << "search_documents called #{count}×, max allowed #{max}"
          end
        end

        if (forbidden_phrases = assertions[:create_task_intent_must_not_contain])
          create_calls = tool_calls.select { |tc| normalize_tool_name(tc.tool) == "create_task" }
          create_calls.each do |tc|
            intent = tc.params.is_a?(Hash) ? tc.params["intent"].to_s : ""
            Array(forbidden_phrases).each do |phrase|
              if intent.downcase.include?(phrase.to_s.downcase)
                failures << "create_task intent contained forbidden phrase: #{phrase.inspect}"
              end
            end
          end
        end

        if (groups = assertions[:allow_either])
          normalized_groups = Array(groups).map { |g| Array(g).map { |t| normalize_tool_name(t) } }
          satisfied = normalized_groups.any? { |group| group.all? { |t| successful_names.include?(t) } }
          unless satisfied
            failures << "allow_either: none of #{normalized_groups.inspect} were fully satisfied (observed non-errored: #{successful_names.uniq.inspect})"
          end
        end

        failures
      end

      # Normalizes MCP wrapper names to their base tool name so that
      # expected/forbidden tools can be written as "create_task" instead of
      # "mcp__director__create_task". Built-in tools (Read, Glob, Bash...)
      # are left unchanged.
      def normalize_tool_name(name)
        return nil if name.nil?
        name.to_s.sub(/\Amcp__director__/, "")
      end

      def write_tempfile(prefix, suffix, content)
        file = Tempfile.new([ prefix, suffix ])
        file.write(content)
        file.flush
        file
      end
  end
end
