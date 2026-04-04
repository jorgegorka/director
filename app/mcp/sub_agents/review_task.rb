module SubAgents
  # Sub-agent for reviewing a task the orchestrator's assignee has submitted
  # for approval. Reads the task and its message history, decides approve or
  # reject, and posts the decision through submit_review_decision. Reviews
  # are the highest-value place to concentrate reasoning -- the old
  # orchestrator prompt tried to inline review guidance next to everything
  # else, which is exactly the bloat we're escaping.
  class ReviewTask < Base
    def self.sub_agent_name
      "review_task"
    end

    def self.tool_scope
      :sub_agent_review_task
    end

    def self.tool_definition
      {
        name: "review_task",
        description: "Delegate reviewing a submitted task to a review specialist. The specialist will read the task, judge whether the work meets the brief, and either approve it or reject it with feedback.",
        inputSchema: {
          type: "object",
          properties: {
            task_id: {
              type: "integer",
              description: "ID of the task pending your review"
            },
            review_focus: {
              type: "string",
              description: "Optional. Specific things you want the specialist to verify (e.g. 'check that the auth flow handles expired tokens')."
            }
          },
          required: [ "task_id" ]
        }
      }
    end

    def system_prompt
      <<~PROMPT
        You are a review specialist working on behalf of #{role.title} at #{role.company.name}. You are reviewing a task that a subordinate has submitted for approval.

        Your single job: decide approve or reject, then submit the decision. Exactly one submit_review_decision call.

        Process:
        1. Call get_task_details on the task. Read:
           - The original description (what was asked for)
           - The assignee's messages (what they say they did)
           - Any subtasks and their statuses
           - The goal context if present
        2. Judge the work against the brief. Be specific, not vague. Look for:
           - Does the submitted work actually satisfy the task description?
           - Are there obvious gaps, half-finished pieces, or misunderstandings?
           - If a review_focus was provided, did the work address it?
        3. Call submit_review_decision exactly once with:
           - decision: "approve" or "reject"
           - feedback: a short paragraph. For approvals: what was done well (optional). For rejections: REQUIRED -- explain concretely what is missing or wrong and what the assignee should do next. Do not be vague ("needs more work" is useless); be actionable.
        4. After the decision is submitted, respond with one sentence summarizing your call and stop.

        Bias: if the work clearly meets the brief, approve. If there is genuine doubt, reject with specific feedback -- it is cheaper to iterate than to accept flawed work.
      PROMPT
    end

    def user_message
      parts = [ "Task id: #{arguments['task_id']}" ]
      parts << "Review focus: #{arguments['review_focus']}" if arguments["review_focus"].present?
      parts.join("\n")
    end

    def build_input_summary
      "task_id=#{arguments['task_id']}"
    end
  end
end
