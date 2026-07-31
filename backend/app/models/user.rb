class User < ApplicationRecord
  # The user's *default* (last-used) account — where magic-link login lands
  # before a workspace is chosen. Access rights come from account_memberships,
  # NOT from this column; never authorize against it.
  belongs_to :account
  has_one :operator_profile, dependent: :destroy
  has_many :assigned_conversations, class_name: "Conversation", foreign_key: :assigned_user_id, dependent: :nullify
  has_many :mcp_grants, dependent: :destroy

  # A user can belong to several accounts ("workspaces" in the UI).
  has_many :account_memberships, dependent: :destroy
  has_many :accounts, through: :account_memberships

  # Legacy account-level role, superseded by AccountMembership#role (a user can
  # be an admin of one workspace and a member of another). Retained so the
  # membership migration stays reversible; read it only as a fallback for rows
  # that predate the backfill.
  enum :role, { member: 0, admin: 1 }, default: :member

  validates :name, presence: true
  # Global uniqueness is load-bearing, not hygiene: MagicLinksController looks
  # users up by bare email, so two rows sharing one would mean an arbitrary —
  # silently wrong — workspace at login. Multi-workspace access is expressed
  # through account_memberships, never through duplicate user rows.
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  scope :super_admins, -> { where(is_super_admin: true) }
  scope :regular_users, -> { where(is_super_admin: false) }

  # Everyone belongs to their default workspace. Doing this here rather than at
  # each call site keeps signup, invites, seeds and demo data consistent — a user
  # created with `account:` but no membership would be locked out of every page.
  after_create :ensure_default_membership

  # Uses the preloaded association when there is one, so list endpoints that
  # `includes(:account_memberships)` don't fire a query per row.
  def membership_for(account)
    return nil unless account
    if account_memberships.loaded?
      account_memberships.find { |m| m.account_id == account.id }
    else
      account_memberships.find_by(account_id: account.id)
    end
  end

  # Whether this user may act in `account` at all. Strict membership — super
  # admins are deliberately NOT auto-members: their cross-account reach is the
  # separate /admin surface, and widening it here would turn every workspace
  # into an implicit one for them.
  def member_of?(account)
    membership_for(account).present?
  end

  # Role within a specific workspace. Falls back to the legacy users.role only
  # when no membership row exists (pre-backfill rows).
  def role_in(account)
    membership_for(account)&.role || role
  end

  # True for admins of `account` and for platform super admins. Passing no
  # account falls back to the user's default workspace.
  def account_admin?(account = self.account)
    return true if is_super_admin?
    role_in(account) == "admin"
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

  private

  def ensure_default_membership
    return if account_id.blank?

    account_memberships.find_or_create_by!(account_id: account_id) do |membership|
      membership.role = role
    end
  end
end
