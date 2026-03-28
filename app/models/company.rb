class Company < ApplicationRecord
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :invitations, dependent: :destroy
  has_many :roles, dependent: :destroy
  has_many :agents, dependent: :destroy
  has_many :skills, dependent: :destroy
  has_many :tasks, dependent: :destroy
  has_many :goals, dependent: :destroy
  has_many :notifications, dependent: :destroy
  has_many :config_versions, dependent: :destroy
  has_many :audit_events, dependent: :delete_all

  validates :name, presence: true

  def admin_recipients
    memberships
      .where(role: [ :owner, :admin ])
      .includes(:user)
      .map(&:user)
  end
end
