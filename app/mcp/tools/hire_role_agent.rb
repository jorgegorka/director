module Tools
  # Orchestrator-facing `hire_role` tool. Delegates to the HireRole
  # sub-agent, which picks the template and budget.
  class HireRoleAgent < SubAgentTool
    self.sub_agent_class = SubAgents::HireRole
  end
end
