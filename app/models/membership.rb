class Membership < ApplicationRecord
  belongs_to :project
  belongs_to :user

  enum :role, { member: 0, admin: 1, owner: 2 }

  validates :role, presence: true
  validates :user_id, uniqueness: { scope: :project_id, message: "is already a member of this project" }
end
