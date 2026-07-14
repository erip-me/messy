class User < ApplicationRecord
  belongs_to :account
  has_one :operator_profile, dependent: :destroy
  has_many :assigned_conversations, class_name: "Conversation", foreign_key: :assigned_user_id, dependent: :nullify
  has_many :mcp_grants, dependent: :destroy

  # Account-level role. :admin can manage users, environments and account
  # settings; :member has read/operate access only. Distinct from is_super_admin,
  # which is the platform-wide (cross-account) super user for the /admin surface.
  enum :role, { member: 0, admin: 1 }, default: :member

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  scope :super_admins, -> { where(is_super_admin: true) }
  scope :regular_users, -> { where(is_super_admin: false) }

  # True for account admins and platform super admins.
  def account_admin?
    admin? || is_super_admin?
  end

  def generate_magic_link_token!
    self.magic_link_token = SecureRandom.hex(10)
    self.magic_link_token_expires_at = 30.minutes.from_now
    save!
  end

  def magic_link_token_valid?
    magic_link_token_expires_at && magic_link_token_expires_at > Time.now
  end

  def reset_magic_link_token!
    self.magic_link_token = nil
    self.magic_link_token_expires_at = nil
    save!
  end
end
