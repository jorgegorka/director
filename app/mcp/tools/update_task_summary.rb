module Tools
  # Internal tool exposed only inside the `sub_agent_summarize_task` MCP
  # scope. The summarize_task sub-agent is the only client -- the
  # orchestrator never sees this tool, because the summary write must flow
  # through the summary specialist.
  class UpdateTaskSummary < BaseTool
    MAX_SUMMARY_LENGTH = 1000

    def name
      "update_task_summary"
    end

    def definition
      {
        name: name,
        description: "Write the achievement summary for a completed root task. Call exactly once, then stop.",
        inputSchema: {
          type: "object",
          properties: {
            task_id: { type: "integer", description: "ID of the root task to summarize" },
            summary: {
              type: "string",
              description: "2-4 sentence plain-text summary of what was achieved. Reference the relevant subtask titles verbatim so the user can click through."
            }
          },
          required: %w[task_id summary]
        }
      }
    end

    def call(arguments)
      task = project.tasks.roots.find(arguments["task_id"])
      validate_permission!(task)

      summary = arguments["summary"].to_s.strip
      raise ArgumentError, "summary is required" if summary.blank?
      raise ArgumentError, "summary is too long (max #{MAX_SUMMARY_LENGTH} chars)" if summary.length > MAX_SUMMARY_LENGTH

      task.update!(summary: summary)

      { status: "ok", task_id: task.id, summary: task.summary }
    end

    private

    def validate_permission!(task)
      return if task.assignee_id.nil?
      return if task.assignee_id == role.id
      return if task.assignee.ancestors.any? { |ancestor| ancestor.id == role.id }

      raise ArgumentError, "You do not have permission to update this task"
    end
  end
end
