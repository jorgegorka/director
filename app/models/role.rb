class Role < ApplicationRecord
  include Tenantable
  include TreeHierarchy
  include ConfigVersioned

  belongs_to :agent, optional: true

  delegate :name, to: :agent, prefix: true, allow_nil: true

  validates :title, presence: true,
                    uniqueness: { scope: :company_id, message: "already exists in this company" }

  before_destroy :reparent_children

  def governance_attributes
    %w[title description job_spec parent_id agent_id]
  end

  private

  def reparent_children
    if parent_id.present? && !Role.exists?(parent_id)
      children.update_all(parent_id: nil)
    else
      children.update_all(parent_id: parent_id)
    end
  end
end
