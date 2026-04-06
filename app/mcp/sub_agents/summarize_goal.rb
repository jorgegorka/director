module SubAgents
  # Sub-agent that writes the achievement summary for a goal that has just
  # reached 100% completion. Triggered by the orchestrator in response to
  # the `goal_completed` hint returned from `submit_review_decision`. Its
  # single job is to read the finished goal's tasks and write a concise,
  # task-referencing summary the user can scan without opening each task.
  class SummarizeGoal < Base
    def self.sub_agent_name
      "summarize_goal"
    end

    def self.tool_scope
      :sub_agent_summarize_goal
    end

    def self.tool_definition
      {
        name: "summarize_goal",
        description: "Delegate writing the achievement summary for a completed goal to a summary specialist. Call this when a tool response includes a goal_completed hint indicating a goal has just reached 100%.",
        inputSchema: {
          type: "object",
          properties: {
            goal_id: {
              type: "integer",
              description: "ID of the goal that just reached 100% completion."
            }
          },
          required: [ "goal_id" ]
        }
      }
    end

    def max_turns
      6
    end

    def system_prompt
      <<~PROMPT
        You are a goal-summary specialist working on behalf of #{role.title} at #{role.company.name}. A goal has just reached 100% completion and needs a short outcome summary for the user.

        Your single job: read the goal and its tasks, then write one concise summary. Exactly one update_goal_summary call.

        Process:
        1. Call get_goal_details on the goal once. Read the title, original description, and every task -- especially their titles, statuses, and reviewer notes. These are the record of what was done.
        2. Write a summary, 2-4 sentences, under 600 characters. It must:
           - Say what was actually delivered (not what was planned).
           - Reference each relevant task as a markdown link: [Task Title](/tasks/ID) using the task's id from get_goal_details. Never use bare titles.
           - Be specific. No filler ("successfully completed the goal"), no restating the goal description.
        3. Call update_goal_summary exactly once with the goal_id and the summary text.
        4. After the summary is written, respond with one short confirmation sentence and stop.

        Do not call any tool more than once. Do not create tasks, update other fields, or start a dialogue.
      PROMPT
    end

    def user_message
      "Goal id: #{arguments['goal_id']}"
    end

    def build_input_summary
      "goal_id=#{arguments['goal_id']}"
    end
  end
end
