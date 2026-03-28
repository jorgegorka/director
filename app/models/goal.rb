class Goal < ApplicationRecord
  include Tenantable
  include TreeHierarchy

  belongs_to :agent, optional: true

  has_many :children, class_name: "Goal", foreign_key: :parent_id, inverse_of: :parent, dependent: :destroy
  has_many :tasks, dependent: :nullify
  has_many :goal_evaluations, dependent: :destroy

  validates :title, presence: true,
                    uniqueness: { scope: [ :company_id, :parent_id ], message: "already exists under this parent" }
  validate :agent_belongs_to_same_company

  scope :ordered, -> { order(:position, :title) }

  def mission?
    root?
  end

  def ancestry_chain
    (ancestors.reverse << self)
  end

  def progress
    all_task_ids = subtree_task_ids
    return 0.0 if all_task_ids.empty?

    total = all_task_ids.size
    completed = Task.where(id: all_task_ids, status: :completed).count
    completed.to_f / total
  end

  def progress_percentage
    (progress * 100).round
  end

  private

  def agent_belongs_to_same_company
    if agent.present? && agent.company_id != company_id
      errors.add(:agent, "must belong to the same company")
    end
  end

  def subtree_task_ids
    goal_ids = [ id ] + descendant_ids
    Task.where(goal_id: goal_ids).pluck(:id)
  end
end
