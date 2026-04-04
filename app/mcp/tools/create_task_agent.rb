module Tools
  # Orchestrator-facing `create_task` tool. Delegates to the CreateTask
  # sub-agent, which reasons about scoping and assignment before writing.
  class CreateTaskAgent < SubAgentTool
    self.sub_agent_class = SubAgents::CreateTask
  end
end
