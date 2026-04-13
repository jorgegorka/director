module Roles::Heartbeats
  extend ActiveSupport::Concern

  included do
    after_commit :sync_heartbeat_schedule, if: :heartbeat_schedule_relevant_change?
  end

  class_methods do
    def scan_due_heartbeats(now: Time.current)
      where("next_heartbeat_at <= ?", now)
        .where(heartbeat_enabled: true)
        .where.not(heartbeat_interval: nil)
        .where.not(status: statuses[:terminated])
        .find_each do |role|
        role.update_column(:next_heartbeat_at, role.heartbeat_interval.minutes.from_now)
        RoleHeartbeatJob.perform_later(role.id)
      end
    end
  end

  def heartbeat_scheduled?
    heartbeat_enabled? && heartbeat_interval.present?
  end

  private
    def heartbeat_schedule_relevant_change?
      saved_change_to_heartbeat_interval? ||
        saved_change_to_heartbeat_enabled? ||
        became_terminated?
    end

    def became_terminated?
      saved_change_to_status? && terminated?
    end

    def sync_heartbeat_schedule
      if heartbeat_scheduled? && !terminated?
        update_column(:next_heartbeat_at, heartbeat_interval.minutes.from_now)
      else
        update_column(:next_heartbeat_at, nil)
      end
    end
end
