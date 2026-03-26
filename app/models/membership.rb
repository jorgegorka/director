class Membership < ApplicationRecord
  belongs_to :company
  belongs_to :user

  enum :role, { member: 0, admin: 1, owner: 2 }

  validates :role, presence: true
  validates :user_id, uniqueness: { scope: :company_id, message: "is already a member of this company" }
end
