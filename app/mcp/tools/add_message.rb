module Tools
  class AddMessage < BaseTool
    def name
      "add_message"
    end

    def definition
      {
        name: name,
        description: "Post a message to a task's thread. You can post on tasks you own (creator or assignee) and on ancestor tasks of any task you're currently assigned to.",
        inputSchema: {
          type: "object",
          properties: {
            task_id: { type: "integer", description: "ID of the task to post to" },
            message: { type: "string", description: "Message content" },
            message_type: { type: "string", enum: %w[comment question], description: "Type of message (default: comment)" }
          },
          required: %w[task_id message]
        }
      }
    end

    def call(arguments)
      task = project.tasks.find(arguments["task_id"])
      authorize_post!(task)

      message = task.messages.create!(
        author: role,
        body: arguments["message"],
        message_type: arguments["message_type"] || "comment"
      )

      { id: message.id, task_id: task.id, message_type: message.message_type }
    end

    private

      def authorize_post!(task)
        return if task.creator_id == role.id
        return if task.assignee_id == role.id
        return if role_assigned_to_descendant_of?(task)

        raise ArgumentError,
              "You can only post on tasks you created, are assigned to, or that are ancestors of a task you're assigned to."
      end

      def role_assigned_to_descendant_of?(task)
        descendant_ids = task.descendant_ids
        return false if descendant_ids.empty?

        role.assigned_tasks.active.where(id: descendant_ids).exists?
      end
  end
end
