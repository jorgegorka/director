module Auditable
  extend ActiveSupport::Concern

  included do
    has_many :audit_events, as: :auditable, dependent: :delete_all
  end

  def record_audit_event!(actor:, action:, metadata: {}, project: nil)
    resolved_project = project || try(:project) || Current.project
    audit_events.create!(
      actor: actor,
      action: action,
      metadata: metadata,
      project: resolved_project
    )
  end
end
