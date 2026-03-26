class Current < ActiveSupport::CurrentAttributes
  attribute :session
  attribute :company
  delegate :user, to: :session, allow_nil: true
end
