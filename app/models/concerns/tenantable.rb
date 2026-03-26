module Tenantable
  extend ActiveSupport::Concern

  included do
    belongs_to :company

    scope :for_current_company, -> { where(company: Current.company) }
  end
end
