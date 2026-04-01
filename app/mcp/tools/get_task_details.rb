module Tools
  class GetTaskDetails < BaseTool
    def name
      "get_task_details"
    end

    def definition
      {
        name: name,
        description: "Get full details of a task including messages, subtasks, and goal context.",
        inputSchema: {
          type: "object",
          properties: {
            task_id: { type: "integer", description: "ID of the task" }
          },
          required: [ "task_id" ]
        }
      }
    end

    def call(arguments)
      task = company.tasks.find(arguments["task_id"])

      messages = task.messages.includes(:author).chronological.map do |msg|
        {
          id: msg.id,
          author: msg.author.respond_to?(:title) ? msg.author.title : msg.author.email_address,
          author_type: msg.author_type,
          body: msg.body,
          message_type: msg.message_type,
          created_at: msg.created_at.iso8601
        }
      end

      subtasks = task.subtasks.map do |st|
        { id: st.id, title: st.title, status: st.status, assignee_id: st.assignee_id }
      end

      result = {
        id: task.id,
        title: task.title,
        description: task.description,
        status: task.status,
        priority: task.priority,
        creator_id: task.creator_id,
        creator_title: task.creator&.title,
        assignee_id: task.assignee_id,
        assignee_title: task.assignee&.title,
        goal_id: task.goal_id,
        parent_task_id: task.parent_task_id,
        reviewed_by_id: task.reviewed_by_id,
        reviewed_at: task.reviewed_at&.iso8601,
        cost_cents: task.cost_cents,
        created_at: task.created_at.iso8601,
        messages: messages,
        subtasks: subtasks
      }

      if task.goal.present?
        result[:goal] = {
          id: task.goal.id,
          title: task.goal.title,
          description: task.goal.description,
          progress_percentage: task.goal.progress_percentage
        }
      end

      result
    end
  end
end
