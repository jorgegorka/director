module Roles
  module Broadcasting
    extend ActiveSupport::Concern

    included do
      after_commit :broadcast_dashboard_update, if: :saved_change_to_status?
    end

    private

    def broadcast_dashboard_update
      broadcast_overview_stats
      broadcast_role_status
      broadcast_running_agents
      broadcast_approvals_badge
      broadcast_org_chart_node
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

    def broadcast_overview_stats
      roles = project.roles.active
      Turbo::StreamsChannel.broadcast_replace_to(
        "dashboard_project_#{project_id}",
        target: "dashboard-overview-stats",
        partial: "dashboard/overview_stats",
        locals: {
          total_roles: roles.count,
          roles_online: roles.online.count,
          tasks_active: project.tasks.active.count,
          tasks_completed: project.tasks.completed.count
        }
      )
    end

    def broadcast_running_agents
      running_roles = project.roles.where(status: :running).includes(role_runs: :task)
      Turbo::StreamsChannel.broadcast_replace_to(
        "dashboard_project_#{project_id}",
        target: "dashboard-running-agents",
        partial: "dashboard/running_agents",
        locals: { running_roles: running_roles }
      )
    end

    def broadcast_approvals_badge
      count = project.approvals_pending_count

      Turbo::StreamsChannel.broadcast_replace_to(
        "dashboard_project_#{project_id}",
        target: "approvals-badge",
        partial: "dashboard/approvals_badge",
        locals: { count: count }
      )
    end
  end
end
