module Tenantable
  extend ActiveSupport::Concern

  included do
    belongs_to :project

    scope :for_current_project, -> { where(project: Current.project) }
  end
end
