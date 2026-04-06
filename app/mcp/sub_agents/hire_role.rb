module SubAgents
  # Sub-agent for hiring a subordinate. Owns the reasoning about which
  # template to pick and how much budget to allocate -- the orchestrator just
  # says "I need more engineering capacity" and this sub-agent figures out
  # the rest.
  class HireRole < Base
    def self.sub_agent_name
      "hire_role"
    end

    def self.tool_scope
      :sub_agent_hire_role
    end

    def self.tool_definition
      {
        name: "hire_role",
        description: "Hire a subordinate role through a hiring specialist. Provide your intent (e.g. 'I need a backend engineer to help with auth work'); the specialist will pick the right template from your department and a reasonable budget.",
        inputSchema: {
          type: "object",
          properties: {
            intent: {
              type: "string",
              description: "What kind of help you need and why. Plain language."
            },
            budget_ceiling_cents: {
              type: "integer",
              description: "Optional hard cap on the new hire's monthly budget, in cents. The specialist will allocate at or below this."
            }
          },
          required: [ "intent" ]
        }
      }
    end

    def system_prompt
      own_budget = role.budget_cents ? "#{role.budget_cents} cents/month" : "uncapped"
      <<~PROMPT
        You are a hiring specialist working on behalf of #{role.title} at #{role.project.name}.

        Your single job: hire exactly ONE subordinate role that matches the intent, or refuse with a reason if no template fits.

        Process:
        1. Call list_hirable_roles to see which templates are available under #{role.title}'s department.
        2. Pick the single best template whose title/description matches the intent. If nothing fits, stop and explain why -- do not force an unrelated hire.
        3. Call hire_role exactly once with:
           - template_role_title: the chosen template's title (must match exactly).
           - budget_cents: a reasonable monthly budget. Constraints:
             * Must be <= your manager's budget (#{own_budget}).
             * If a budget_ceiling_cents was provided in the intent, do not exceed it.
             * Default to ~25% of the manager's budget when unconstrained, or the ceiling if lower.
        4. Respond with one sentence confirming the hire and stop.

        Do not create tasks. Do not hire more than once. Do not suggest multiple candidates -- commit to one.
      PROMPT
    end

    def user_message
      parts = [ "Intent: #{arguments['intent']}" ]
      parts << "Budget ceiling: #{arguments['budget_ceiling_cents']} cents" if arguments["budget_ceiling_cents"].present?
      parts.join("\n")
    end

    def build_input_summary
      "intent=#{arguments['intent'].to_s.truncate(120)}"
    end
  end
end
