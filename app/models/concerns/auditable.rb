module Auditable
  extend ActiveSupport::Concern

  included do
    has_many :audit_events, as: :auditable, dependent: :destroy
  end

  def record_audit_event!(actor:, action:, metadata: {})
    audit_events.create!(
      actor: actor,
      action: action,
      metadata: metadata
    )
  end
end
