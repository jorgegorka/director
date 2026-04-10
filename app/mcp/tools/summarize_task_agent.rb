module Tools
  # Orchestrator-facing `summarize_task` tool. Delegates to the SummarizeTask
  # sub-agent, which reads the finished root task's subtasks and writes a
  # short outcome summary for the user.
  class SummarizeTaskAgent < SubAgentTool
    self.sub_agent_class = SubAgents::SummarizeTask
  end
end
