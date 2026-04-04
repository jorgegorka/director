module SubAgents
  # Sub-agent that takes a high-level intent from the orchestrator and turns
  # it into exactly one well-scoped, well-assigned task. It owns the
  # reasoning that used to be inlined in the orchestrator's system prompt:
  # writing a useful description, picking the right assignee, sizing work.
  class CreateTask < Base
    def self.sub_agent_name
      "create_task"
    end

    def self.tool_scope
      :sub_agent_create_task
    end

    def self.tool_definition
      {
        name: "create_task",
        description: "Create a new task through a task-creation specialist. Provide a brief intent; the specialist will write a detailed description, select the right assignee from your subordinates or siblings, and create the task. Use this instead of writing task descriptions inline.",
        inputSchema: {
          type: "object",
          properties: {
            intent: {
              type: "string",
              description: "Plain-language description of what needs to happen. Don't worry about formatting -- the specialist will write the final task. Include any constraints, deadlines, or context the specialist should know."
            },
            goal_id: {
              type: "integer",
              description: "ID of the goal this task advances (optional but strongly recommended)."
            },
            parent_task_id: {
              type: "integer",
              description: "ID of the parent task when creating a subtask (optional)."
            },
            suggested_assignee_role_id: {
              type: "integer",
              description: "Optional. If you already know who should do this work, pass their role id. The specialist may still override."
            }
          },
          required: [ "intent" ]
        }
      }
    end

    def system_prompt
      <<~PROMPT
        You are a task-creation specialist working on behalf of #{role.title} at #{role.company.name}.

        Your single job: convert a brief intent into ONE well-scoped task and create it. Do not do the work itself, do not split into multiple tasks, do not start a dialogue.

        Process:
        1. If a goal_id was provided, call get_goal_details to understand the goal's context and existing tasks. Do NOT create work that duplicates or overlaps with existing tasks on the goal.
        2. Call list_available_roles to see who can be assigned work. Pick the single best assignee based on the intent:
           - Prefer subordinates over siblings.
           - Prefer roles whose description matches the work.
           - If a suggested_assignee_role_id was provided, use it unless it's clearly wrong.
        3. Call create_task exactly once with:
           - A clear, imperative title (under 80 characters).
           - A description that includes WHAT to do, WHY it matters, and any constraints the intent mentioned. Do not restate the intent verbatim -- rewrite it as an actionable brief for the assignee.
           - The chosen assignee_role_id.
           - The goal_id and parent_task_id if they were provided.
           - A priority (default: medium; use high only if the intent explicitly says urgent/important).
        4. After create_task returns, respond with a single sentence confirming the task id and assignee. Then stop.

        Do not call any tool more than once unnecessarily. Do not hire roles. Do not update other tasks.
      PROMPT
    end

    def user_message
      parts = [ "Intent: #{arguments['intent']}" ]
      parts << "Goal id: #{arguments['goal_id']}" if arguments["goal_id"].present?
      parts << "Parent task id: #{arguments['parent_task_id']}" if arguments["parent_task_id"].present?
      parts << "Suggested assignee role id: #{arguments['suggested_assignee_role_id']}" if arguments["suggested_assignee_role_id"].present?
      parts.join("\n")
    end

    def build_input_summary
      "intent=#{arguments['intent'].to_s.truncate(120)} goal_id=#{arguments['goal_id']}"
    end
  end
end
