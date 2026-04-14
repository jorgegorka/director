module Tools
  # Base class for MCP tools that delegate to a SubAgents::Base subclass.
  # A sub-agent tool looks like a regular MCP tool to the orchestrator --
  # same name, same input schema -- but its #call spawns a focused LLM loop
  # that owns the reasoning for that operation.
  class SubAgentTool < BaseTool
    class_attribute :sub_agent_class, instance_writer: false

    def name
      self.class.sub_agent_class.tool_definition[:name]
    end

    def definition
      self.class.sub_agent_class.tool_definition
    end

    # Queue the sub-agent as a background job and return immediately with an
    # invocation handle. The synchronous path here used to block for ~30s
    # while `claude -p` spawned, which tripped the parent CLI's 2s MCP tool
    # timeout and corrupted the connection. See
    # `test/aim/results/diagnostics/20260414_083911_followup.md`.
    def call(arguments)
      parent_role_run = role.active_or_latest_run
      sub_agent_class = self.class.sub_agent_class

      # No RoleRun for this role -- shouldn't happen in production (MCP tools
      # only fire inside an active run) but tests and one-offs can hit it.
      # Run synchronously so work isn't silently dropped.
      if parent_role_run.nil?
        return sub_agent_class.new(role: role, arguments: arguments, parent_role_run: nil).call
      end

      input_summary = sub_agent_class.new(
        role: role,
        arguments: arguments,
        parent_role_run: parent_role_run
      ).build_input_summary

      invocation = sub_agent_class.enqueue(
        role: role,
        arguments: arguments,
        parent_role_run: parent_role_run,
        input_summary: input_summary
      )

      {
        status: "queued",
        sub_agent_invocation_id: invocation.id,
        sub_agent: sub_agent_class.sub_agent_name,
        message: "Running in background. Check list_my_tasks on your next turn; use get_sub_agent_invocation only if you need invocation-level status."
      }
    end
  end
end
