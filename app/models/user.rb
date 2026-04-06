class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :projects, through: :memberships
  has_many :notifications, as: :recipient, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true,
    format: { with: URI::MailTo::EMAIL_REGEXP }

  def unread_notification_count(project: nil)
    scope = notifications
    scope = scope.where(project: project) if project
    scope.unread.count
  end
end
