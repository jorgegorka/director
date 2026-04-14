module Tools
  # Orchestrator-facing poll tool for a single SubAgentInvocation. Pure poll:
  # returns the current status immediately without blocking -- anything else
  # risks re-tripping the 2s MCP tool-call timeout we rely on this tool to
  # work around. The orchestrator calls it on subsequent turns to check on
  # sub-agent jobs enqueued by create_task / review_task / hire_role /
  # summarize_task.
  class GetSubAgentInvocation < BaseTool
    def name
      "get_sub_agent_invocation"
    end

    def definition
      {
        name: name,
        description: "Fetch the status of a background sub-agent invocation (queued, running, completed, failed) along with its result or error. Use this to check whether a previously-issued create_task / review_task / hire_role / summarize_task call has finished.",
        inputSchema: {
          type: "object",
          properties: {
            invocation_id: {
              type: "integer",
              description: "ID returned as sub_agent_invocation_id from a sub-agent tool call."
            }
          },
          required: [ "invocation_id" ]
        }
      }
    end

    def call(arguments)
      project.sub_agent_invocations.find(arguments["invocation_id"]).as_tool_payload
    end
  end
end
