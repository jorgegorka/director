module Roles
  module Broadcasting
    extend ActiveSupport::Concern

    included do
      after_commit :broadcast_dashboard_update, if: :saved_change_to_status?
    end

    private

    def broadcast_dashboard_update
      broadcast_role_status
      broadcast_org_chart_node
      broadcast_goal_cards
      broadcast_attention_section
    end

    def broadcast_org_chart_node
      Turbo::StreamsChannel.broadcast_replace_to(
        "org_chart_project_#{project_id}",
        target: "org-chart-node-#{id}",
        partial: "roles/org_chart_node",
        locals: { role: self }
      )
    end

    def broadcast_role_status
      Turbo::StreamsChannel.broadcast_replace_to(
        "role_#{id}",
        target: "role-status-badge-#{id}",
        partial: "roles/status_badge",
        locals: { role: self }
      )
    end

    def broadcast_goal_cards
      assigned_tasks.roots.includes(:assignee, :subtasks).each do |goal|
        Turbo::StreamsChannel.broadcast_replace_to(
          "dashboard_project_#{project_id}",
          target: "goal_card_task_#{goal.id}",
          partial: "dashboard/goal_card",
          locals: { goal: goal }
        )
      end
    rescue ActionView::Template::Error, ActiveRecord::StatementInvalid => e
      Rails.logger.warn("[Role##{id}] goal cards broadcast failed: #{e.message}")
    end

    def broadcast_attention_section
      Dashboard::AttentionItems.new(project).broadcast_to(project_id)
    rescue ActionView::Template::Error, ActiveRecord::StatementInvalid => e
      Rails.logger.warn("[Role##{id}] attention section broadcast failed: #{e.message}")
    end
  end
end
