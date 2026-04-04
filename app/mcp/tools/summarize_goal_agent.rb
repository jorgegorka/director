module Tools
  # Orchestrator-facing `summarize_goal` tool. Delegates to the SummarizeGoal
  # sub-agent, which reads the finished goal's tasks and writes a short
  # outcome summary for the user.
  class SummarizeGoalAgent < SubAgentTool
    self.sub_agent_class = SubAgents::SummarizeGoal
  end
end
