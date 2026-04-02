class RoleCategory < ApplicationRecord
  include Tenantable

  has_many :roles, dependent: :restrict_with_error

  validates :name, presence: true,
                   uniqueness: { scope: :company_id, message: "already exists in this company" }
  validates :job_spec, presence: true

  def self.default_definitions
    @default_definitions ||= YAML.load_file(Rails.root.join("db/seeds/role_categories.yml")).freeze
  end

  def self.reset_default_definitions!
    @default_definitions = nil
  end
end
