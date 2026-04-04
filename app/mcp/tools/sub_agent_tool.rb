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

    def call(arguments)
      self.class.sub_agent_class.new(
        role: role,
        arguments: arguments,
        parent_role_run: resolve_parent_role_run
      ).call
    end

    private
      # The MCP process is handling tool calls from a running outer Claude CLI,
      # so there is (by construction) an active RoleRun for this role -- that's
      # the one whose cost we roll sub-agent spend into. Fall back to the most
      # recent run if the active lookup misses; the alternative is a crash and
      # that's worse than attributing cost to the last known run.
      def resolve_parent_role_run
        role.role_runs.where(status: :running).order(created_at: :desc).first ||
          role.role_runs.order(created_at: :desc).first
      end
  end
end
