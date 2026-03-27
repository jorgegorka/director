module Auditable
  extend ActiveSupport::Concern

  included do
    has_many :audit_events, as: :auditable, dependent: :delete_all
  end

  def record_audit_event!(actor:, action:, metadata: {}, company: nil)
    resolved_company = company || try(:company) || Current.company
    audit_events.create!(
      actor: actor,
      action: action,
      metadata: metadata,
      company: resolved_company
    )
  end
end
