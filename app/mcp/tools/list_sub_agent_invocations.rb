module Tools
  # Orchestrator-facing list tool for recent SubAgentInvocation records tied
  # to the current RoleRun. Lets the orchestrator see every queued / running
  # sub-agent it kicked off this turn without knowing each invocation id.
  class ListSubAgentInvocations < BaseTool
    DEFAULT_LIMIT = 10
    MAX_LIMIT = 50

    def name
      "list_sub_agent_invocations"
    end

    def definition
      {
        name: name,
        description: "List the most recent sub-agent invocations kicked off from your current run (queued, running, completed, or failed). Use this to see the status of background sub-agent jobs you started via create_task / review_task / hire_role / summarize_task.",
        inputSchema: {
          type: "object",
          properties: {
            limit: {
              type: "integer",
              description: "Max number of invocations to return. Defaults to 10, capped at 50."
            }
          }
        }
      }
    end

    def call(arguments)
      run = role.active_or_latest_run
      return { invocations: [], count: 0 } unless run

      limit = arguments["limit"].blank? ? DEFAULT_LIMIT : arguments["limit"].to_i.clamp(1, MAX_LIMIT)

      records = run.sub_agent_invocations.recent.limit(limit)
      { invocations: records.map(&:as_tool_payload), count: records.size }
    end
  end
end
