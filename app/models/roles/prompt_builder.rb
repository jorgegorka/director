module Roles
  module PromptBuilder
    extend ActiveSupport::Concern

    # Composes the full system prompt from contextual + behavioral parts.
    # Adapters that support system prompts call this directly.
    def compose_system_prompt(context)
      parts = []
      parts << build_identity_prompt
      parts << job_spec if job_spec.present?
      parts << role_category.job_spec if role_category&.job_spec.present?
      parts << build_root_task_prompt(context) if context[:root_task_title].present?
      parts << build_skills_prompt(context[:skills]) if context[:skills].present?
      parts.join("\n\n")
    end

    # Composes the user prompt (task assignment, review trigger, or default).
    def build_user_prompt(context)
      body = if context[:trigger_type] == "task_pending_review" && context[:task_id].present?
        build_review_prompt(context)
      elsif context[:task_id].present?
        build_task_assignment_prompt(context)
      else
        "Check your assigned tasks with list_my_tasks, then execute the highest-priority work."
      end

      [ build_human_feedback_prompt(context), body ].compact_blank.join("\n\n")
    end

    # For adapters without system prompt support: merges system + user into one.
    def compose_unified_prompt(context)
      system = compose_system_prompt(context)
      user = build_user_prompt(context)
      [ system, user ].compact_blank.join("\n\n---\n\n")
    end

    private

    # Contextual identity: role title, project, org chart.
    # Behavioral instructions live in role_category.job_spec, not here.
    def build_identity_prompt
      project_name = project&.name || "Unknown Project"
      manager = parent
      children_roles = children.active.order(:title).to_a

      manager_line = manager ? manager.title : "None (top-level role)"
      reports_line = if children_roles.any?
        children_roles.map(&:title).join(", ")
      else
        "None yet — you can hire subordinates using the hire_role tool"
      end

      <<~PROMPT.strip
        ## Your Identity

        You are **#{title}** at **#{project_name}**.
        #{description.present? ? "\n#{description}\n" : ""}
        ## Your Organization

        Manager: #{manager_line}
        Direct reports: #{reports_line}
      PROMPT
    end

    def build_root_task_prompt(context)
      prompt = "## Mission Context\n\n**#{context[:root_task_title]}**"
      prompt += "\n\n#{context[:root_task_description]}" if context[:root_task_description].present?
      prompt += <<~FOCUS

        ## Focus Rules

        Everything you do in this session must directly advance the mission above.
        - Do NOT start work outside this mission's scope.
        - If you spot a related opportunity or risk, use `add_message` to flag it — do not act on it.
      FOCUS
      prompt.strip
    end

    def build_skills_prompt(skills)
      catalog = skills.map { |s|
        line = "- **#{s[:name]}** (#{s[:key]}): #{s[:description]}"
        if s[:linked_documents].present?
          doc_names = s[:linked_documents].map { |d| "\"#{d[:title]}\"" }.join(", ")
          line += "\n  Related docs: #{doc_names}"
        end
        line
      }.join("\n")
      details = skills.map { |s| "<skill key=\"#{s[:key]}\">\n#{s[:markdown]}\n</skill>" }.join("\n\n")

      <<~PROMPT.strip
        ## Your Skills

        You have the following skills. Before starting work, identify which skill is most relevant to the current task and follow its instructions.

        #{catalog}

        ### Skill Instructions

        #{details}
      PROMPT
    end

    def build_human_feedback_prompt(context)
      return nil if context[:human_feedback].blank?

      <<~PROMPT.strip
        ## Human Feedback

        A human reviewer left this feedback for you. Read it carefully and let it shape the work that follows.

        > #{context[:human_feedback]}
      PROMPT
    end

    def build_review_prompt(context)
      prompt = "Task ##{context[:task_id]} is pending your review"
      prompt += ": #{context[:task_title]}" if context[:task_title].present?
      prompt += "\n\n#{context[:assignee_role_title]} has submitted this task for review." if context[:assignee_role_title].present?
      prompt += "\n\nHand this off to the review_task specialist -- do not read the task and decide yourself."
      prompt.strip
    end

    def build_task_assignment_prompt(context)
      prompt = "You have been assigned Task ##{context[:task_id]}"
      prompt += ": #{context[:task_title]}" if context[:task_title].present?
      prompt += "\n\n#{context[:task_description]}" if context[:task_description].present?

      if context[:task_documents].present?
        prompt += "\n\n## Reference Documents\n\n"
        prompt += context[:task_documents].map { |d|
          "<document title=\"#{d[:title]}\">\n#{d[:body]}\n</document>"
        }.join("\n\n")
      end

      if context[:active_subtasks].present?
        subtask_list = context[:active_subtasks].map { |t| "- Task ##{t[:id]}: #{t[:title]} (#{t[:status]})" }.join("\n")
        prompt += "\n\n## Active Subtasks\n\n#{subtask_list}"
        prompt += "\n\nThis root task already has work in progress. Focus on completing the existing subtasks above — do NOT create new subtasks unless all current ones are completed or blocked and more work is clearly needed."
      end

      prompt += "\n\nThe task is already marked in_progress. The details above are complete — start working immediately."
      prompt.strip
    end
  end
end
