module SubAgents
  # Abstract base class for focused sub-agents. A sub-agent runs as a short,
  # scoped `claude -p` subprocess spawned from inside the MCP tool handler --
  # it inherits the parent orchestrator's auth and MCP machinery but sees
  # only a narrow tool set (selected by tool_scope). Its one job is to take
  # a single agentic decision on the orchestrator's behalf.
  class Base
    DEFAULT_MAX_TURNS = 30

    attr_reader :role, :arguments, :parent_role_run

    def self.sub_agent_name
      raise NotImplementedError
    end

    def self.tool_scope
      raise NotImplementedError
    end

    def self.tool_definition
      raise NotImplementedError
    end

    def initialize(role:, arguments:, parent_role_run:, runner: nil)
      @role = role
      @arguments = arguments
      @parent_role_run = parent_role_run
      @runner = runner
    end

    # Runs the sub-agent and returns a hash that will be serialized back to
    # the orchestrator as the MCP tool result.
    def call
      (@runner || Runner.new).run(self)
    end

    # Below: subclass-facing API. Override as needed.

    def max_turns
      DEFAULT_MAX_TURNS
    end

    # Model for the sub-agent's subprocess. nil means "inherit the parent
    # role's configured model". Sub-agents can override to pick a smaller,
    # cheaper model once we have confidence in the split.
    def model
      nil
    end

    def system_prompt
      raise NotImplementedError
    end

    def user_message
      raise NotImplementedError
    end

    def build_input_summary
      arguments.to_json
    end

    # Queue this sub-agent class to run in a background job and return the
    # newly-created queued SubAgentInvocation. Both the orchestrator-facing
    # MCP wrapper and any in-process chain (e.g. ReviewTask → SummarizeTask)
    # go through here so the queue/dispatch contract lives in one place.
    def self.enqueue(role:, arguments:, parent_role_run:, input_summary: nil)
      invocation = SubAgentInvocation.enqueue!(
        role_run: parent_role_run,
        sub_agent_name: sub_agent_name,
        input_summary: input_summary
      )
      SubAgentJob.perform_later(
        invocation.id,
        name,
        role.id,
        arguments,
        parent_role_run.id
      )
      invocation
    end
  end
end
