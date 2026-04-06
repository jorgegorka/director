class Current < ActiveSupport::CurrentAttributes
  attribute :session
  attribute :project
  delegate :user, to: :session, allow_nil: true
end
