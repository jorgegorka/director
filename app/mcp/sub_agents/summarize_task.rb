module SubAgents
  # Sub-agent that writes the achievement summary for a root task that
  # just reached 100% completion. Triggered by the orchestrator in response
  # to the `root_task_completed` hint returned from `submit_review_decision`.
  # Its single job is to read the finished root task's subtasks and write a
  # concise, subtask-referencing summary the user can scan without opening
  # each task.
  class SummarizeTask < Base
    def self.sub_agent_name
      "summarize_task"
    end

    def self.tool_scope
      :sub_agent_summarize_task
    end

    def self.tool_definition
      {
        name: "summarize_task",
        description: "Delegate writing the achievement summary for a completed root task to a summary specialist. Call this when a tool response includes a root_task_completed hint indicating a root task has just reached 100%.",
        inputSchema: {
          type: "object",
          properties: {
            task_id: {
              type: "integer",
              description: "ID of the root task that just reached 100% completion."
            }
          },
          required: [ "task_id" ]
        }
      }
    end

    def max_turns
      6
    end

    def system_prompt
      <<~PROMPT
        You are a task-summary specialist working on behalf of #{role.title} at #{role.project.name}. A root task has just reached 100% completion and needs a short outcome summary for the user.

        Your single job: read the root task and its subtasks, then write one concise summary. Exactly one update_task_summary call.

        Process:
        1. Call get_task_details on the root task once. Read the title, original description, and every subtask -- especially their titles, statuses, and reviewer notes. These are the record of what was done.
        2. Write a summary, 2-4 sentences, under 600 characters. It must:
           - Say what was actually delivered (not what was planned).
           - Reference each relevant subtask as a markdown link: [Task Title](/tasks/ID) using the subtask id from get_task_details. Never use bare titles.
           - Be specific. No filler ("successfully completed the task"), no restating the root description.
        3. Call update_task_summary exactly once with the root task_id and the summary text.
        4. After the summary is written, respond with one short confirmation sentence and stop.

        Do not call any tool more than once. Do not create tasks, update other fields, or start a dialogue.
      PROMPT
    end

    def user_message
      "Root task id: #{arguments['task_id']}"
    end

    def build_input_summary
      "task_id=#{arguments['task_id']}"
    end
  end
end
