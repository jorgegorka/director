module Tools
  # Internal tool exposed only inside the `sub_agent_summarize_goal` MCP
  # scope. The summarize_goal sub-agent is the only client -- the
  # orchestrator never sees this tool, because the summary write must flow
  # through the summary specialist.
  class UpdateGoalSummary < BaseTool
    MAX_SUMMARY_LENGTH = 1000

    def name
      "update_goal_summary"
    end

    def definition
      {
        name: name,
        description: "Write the achievement summary for a completed goal. Call exactly once, then stop.",
        inputSchema: {
          type: "object",
          properties: {
            goal_id: { type: "integer", description: "ID of the goal to summarize" },
            summary: {
              type: "string",
              description: "2-4 sentence plain-text summary of what was achieved. Reference the relevant task titles verbatim so the user can click through."
            }
          },
          required: %w[goal_id summary]
        }
      }
    end

    def call(arguments)
      goal = company.goals.find(arguments["goal_id"])
      validate_permission!(goal)

      summary = arguments["summary"].to_s.strip
      raise ArgumentError, "summary is required" if summary.blank?
      raise ArgumentError, "summary is too long (max #{MAX_SUMMARY_LENGTH} chars)" if summary.length > MAX_SUMMARY_LENGTH

      goal.update!(summary: summary)

      { status: "ok", goal_id: goal.id, summary: goal.summary }
    end

    private

    def validate_permission!(goal)
      return if goal.role_id.nil?
      return if goal.role_id == role.id
      return if goal.role.ancestors.any? { |ancestor| ancestor.id == role.id }

      raise ArgumentError, "You do not have permission to update this goal"
    end
  end
end
