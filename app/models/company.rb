class Company < ApplicationRecord
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :invitations, dependent: :destroy
  has_many :roles, dependent: :destroy
  has_many :agents, dependent: :destroy
  has_many :tasks, dependent: :destroy

  validates :name, presence: true
end
