module Tools
  # Orchestrator-facing `review_task` tool. Delegates to the ReviewTask
  # sub-agent, which reads the submission and decides approve/reject.
  class ReviewTaskAgent < SubAgentTool
    self.sub_agent_class = SubAgents::ReviewTask
  end
end
