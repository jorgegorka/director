module Enableable
  extend ActiveSupport::Concern

  included do
    scope :enabled, -> { where(enabled: true) }
    scope :disabled, -> { where(enabled: false) }
  end
end
