class Role < ApplicationRecord
  include Tenantable

  belongs_to :parent, class_name: "Role", optional: true
  has_many :children, class_name: "Role", foreign_key: :parent_id, dependent: :nullify, inverse_of: :parent

  validates :title, presence: true
  validates :title, uniqueness: { scope: :company_id, message: "already exists in this company" }
  validate :parent_belongs_to_same_company
  validate :parent_is_not_self
  validate :parent_is_not_descendant

  scope :roots, -> { where(parent_id: nil) }

  def ancestors
    result = []
    current = parent
    while current
      result << current
      current = current.parent
    end
    result
  end

  def descendants
    children.flat_map { |child| [ child ] + child.descendants }
  end

  def root?
    parent_id.nil?
  end

  def depth
    ancestors.size
  end

  private

  def parent_belongs_to_same_company
    if parent.present? && parent.company_id != company_id
      errors.add(:parent, "must belong to the same company")
    end
  end

  def parent_is_not_self
    if parent_id.present? && parent_id == id
      errors.add(:parent, "cannot be the role itself")
    end
  end

  def parent_is_not_descendant
    if parent_id.present? && id.present? && descendants.map(&:id).include?(parent_id)
      errors.add(:parent, "cannot be a descendant of this role")
    end
  end
end
