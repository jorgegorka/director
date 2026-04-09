module Tasks
  module Broadcasting
    extend ActiveSupport::Concern

    included do
      after_commit :broadcast_kanban_update, on: [ :create, :update ]
      after_commit :broadcast_kanban_remove, on: :destroy
      after_commit :broadcast_approvals_badge, on: [ :create, :update ], if: :pending_review_changed?
    end

    private

    def pending_review_changed?
      saved_change_to_status? && (pending_review? || status_before_last_save == "pending_review")
    end

    def broadcast_kanban_update
      return unless project_id
      Turbo::StreamsChannel.broadcast_remove_to(
        "dashboard_project_#{project_id}",
        target: "kanban-task-#{id}"
      )
      Turbo::StreamsChannel.broadcast_append_to(
        "dashboard_project_#{project_id}",
        target: "kanban-column-body-#{status}",
        partial: "dashboard/kanban_card",
        locals: { task: self }
      )
    end

    def broadcast_kanban_remove
      return unless project_id
      Turbo::StreamsChannel.broadcast_remove_to(
        "dashboard_project_#{project_id}",
        target: "kanban-task-#{id}"
      )
    end

    def broadcast_approvals_badge
      return unless project_id

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
