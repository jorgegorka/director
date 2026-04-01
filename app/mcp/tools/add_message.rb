module Tools
  class AddMessage < BaseTool
    def name
      "add_message"
    end

    def definition
      {
        name: name,
        description: "Post a message to a task's thread. You must be the creator or assignee of the task.",
        inputSchema: {
          type: "object",
          properties: {
            task_id: { type: "integer", description: "ID of the task to post to" },
            body: { type: "string", description: "Message content" },
            message_type: { type: "string", enum: %w[comment question], description: "Type of message (default: comment)" }
          },
          required: %w[task_id body]
        }
      }
    end

    def call(arguments)
      task = company.tasks.find(arguments["task_id"])

      unless task.creator_id == role.id || task.assignee_id == role.id
        raise ArgumentError, "You must be the creator or assignee of this task to post messages"
      end

      message = task.messages.create!(
        author: role,
        body: arguments["body"],
        message_type: arguments["message_type"] || "comment"
      )

      { id: message.id, task_id: task.id, message_type: message.message_type }
    end
  end
end
