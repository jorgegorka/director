module Tools
  # Orchestrator-facing `review_task` tool. Delegates to the ReviewTask
  # sub-agent in the background. When the review job approves a subtask that
  # causes its root to reach 100% completion, SubAgentJob automatically
  # enqueues a follow-up SummarizeTask invocation.
  class ReviewTaskAgent < SubAgentTool
    self.sub_agent_class = SubAgents::ReviewTask
  end
end
