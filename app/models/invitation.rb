class Invitation < ApplicationRecord
  EXPIRATION_PERIOD = 30.days

  belongs_to :company
  belongs_to :inviter, class_name: "User"

  enum :role, { member: 0, admin: 1 }
  enum :status, { pending: 0, accepted: 1, expired: 2 }

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :token, presence: true, uniqueness: true
  validates :role, presence: true
  validates :expires_at, presence: true
  validate :invitee_not_already_member, on: :create

  before_validation :generate_token, on: :create
  before_validation :set_expiration, on: :create

  scope :active, -> { pending.where("expires_at > ?", Time.current) }

  def expired?
    expires_at <= Time.current
  end

  def acceptable?
    pending? && !expired?
  end

  def accept!(user)
    transaction do
      company.memberships.create!(user: user, role: role)
      update!(status: :accepted, accepted_at: Time.current)
    end
  end

  private

  def generate_token
    self.token ||= SecureRandom.urlsafe_base64(32)
  end

  def set_expiration
    self.expires_at ||= EXPIRATION_PERIOD.from_now
  end

  def invitee_not_already_member
    if company && email_address.present?
      existing_user = User.find_by(email_address: email_address)
      if existing_user && company.memberships.exists?(user: existing_user)
        errors.add(:email_address, "is already a member of this company")
      end
    end
  end
end
