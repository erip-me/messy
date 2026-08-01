class UsersController < ApplicationController
  before_action :authenticate_user!, except: [:me]
  before_action :set_account, except: [:me]
  before_action :require_account_admin!, only: %i[create update destroy invitations revoke_invitation]
  before_action :set_user, only: %i[show update destroy]

  # GET /users
  def index
    @users = @account.users.includes(:account_memberships, operator_profile: { avatar_attachment: :blob })
    render json: UserResource.new(@users, params: { account: @account }).serialize
  end

  # GET /users/invitations — outstanding invitations for this workspace.
  #
  # Deliberately only the address the admin typed and the role they chose. An
  # invitee who hasn't accepted is not a member, so nothing about the person
  # behind that address is disclosed.
  def invitations
    memberships = @account.account_memberships.pending.includes(:user).order(:created_at)
    render json: memberships.map { |m|
      { id: m.id, email: m.user.email, role: m.role, created_at: m.created_at }
    }
  end

  # DELETE /users/invitations/:id — withdraw an invitation that hasn't been
  # accepted (mistyped address, changed mind).
  def revoke_invitation
    @account.account_memberships.pending.find(params[:id]).destroy!
    head :no_content
  end

  # GET /users/1
  def show
    render json: UserResource.new(@user, params: { account: @account }).serialize
  end

  # POST /users
  def create
    email = params[:email].to_s.strip.downcase
    existing = User.find_by(email: email)

    # Someone who already has a login is *invited* to this workspace rather than
    # re-registered — one User row per person, many memberships. The membership
    # is pending until they accept: being named by a workspace admin is not
    # consent, and until they agree none of their profile is exposed here.
    if existing
      case existing.membership_for(@account)
      when nil
        AccountMembership.create!(user: existing, account: @account,
                                  role: invited_role, accepted_at: nil)
        UserMailer.with(user: existing, inviter: current_user, account: @account)
                  .workspace_invitation_email.deliver_later
        # Only the address the admin typed. There is no member to serialize yet,
        # and echoing the account behind that address would be the disclosure
        # this whole flow exists to prevent.
        return render json: { status: 'invited', email: email, role: invited_role.to_s },
                      status: :created
      when ->(m) { m.pending? }
        return render json: { message: 'That person has already been invited' },
                      status: :unprocessable_entity
      else
        return render json: { message: 'That person is already in this workspace' },
                      status: :unprocessable_entity
      end
    end

    # `account:` makes this their default workspace; User#ensure_default_membership
    # grants the membership with this role.
    @user = User.new(name: params[:name], email: email, account: @account, role: invited_role)
    @user.save!

    @user.generate_magic_link_token!
    UserMailer.with(user: @user, inviter: current_user).invitation_email.deliver_later
    render json: UserResource.new(@user, params: { account: @account }).serialize, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { message: e.record.errors.full_messages.join(', ') }, status: :unprocessable_entity
  end

  # PATCH/PUT /users/1
  def update
    if demoting_last_admin?
      return render json: { message: "You can't remove the last admin of the workspace" }, status: :unprocessable_entity
    end

    ActiveRecord::Base.transaction do
      # Role is per-workspace, so it lands on the membership, not the user.
      if user_params.key?(:role)
        membership.update!(role: user_params[:role])
      end
      @user.update!(user_params.except(:role))
    end

    render json: UserResource.new(@user.reload, params: { account: @account }).serialize
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  # DELETE /users/1
  def destroy
    if last_account_admin?(@user)
      return render json: { message: "You can't remove the last admin of the workspace" }, status: :unprocessable_entity
    end

    # Removing someone from a workspace they share with others must not delete
    # their login — drop the membership and only destroy the user if this was
    # their last workspace.
    other_memberships = @user.account_memberships.where.not(account_id: @account.id)

    if other_memberships.exists?
      ActiveRecord::Base.transaction do
        membership.destroy!
        # Their default workspace pointed here; move it somewhere they still belong.
        if @user.account_id == @account.id
          @user.update_column(:account_id, other_memberships.order(:created_at).pick(:account_id))
        end
      end
    else
      @user.destroy!
    end
  end

  def me
    authenticate_user!
    return unless current_user

    # Role is per-workspace and the SPA gates admin UI on it, so report it for the
    # workspace the caller is actually in — not their default one.
    render json: {
      user: UserResource.new(current_user, params: { account: resolved_account }).to_h,
      workspaces: workspaces_for(current_user),
      pending_workspaces: pending_workspaces_for(current_user),
      token: generate_jwt(current_user)
    }, status: :ok
  end

  private

  def set_account
    @account = resolved_account
  end

  def set_user
    @user = @account.users.find(params[:id])
  end

  # The target user's membership in the workspace being administered.
  def membership
    @membership ||= @user.membership_for(@account)
  end

  # Environments ride along so the SPA can offer one workspace/environment picker
  # without a round trip per workspace. Name and id only — an environment's API
  # key is never part of this list.
  def workspaces_for(user)
    # An operator profile belongs to one workspace (user_id is unique), so the
    # avatar is offered to that workspace's row only — not reused as this
    # person's face everywhere.
    profile = user.operator_profile
    avatar_url =
      if profile&.avatar&.attached?
        Rails.application.routes.url_helpers.rails_blob_url(profile.avatar)
      end

    user.account_memberships.accepted.includes(account: :environments).map do |m|
      {
        id: m.account_id,
        name: m.account.name,
        role: m.role,
        avatar_url: (avatar_url if profile&.account_id == m.account_id),
        environments: m.account.environments.map { |e| { id: e.id, name: e.name } }
      }
    end
  end

  # Invitations awaiting this person's decision. Only the workspace's own name —
  # nothing about who else is in it.
  def pending_workspaces_for(user)
    user.account_memberships.pending.includes(:account).map do |m|
      { id: m.account_id, name: m.account.name, role: m.role }
    end
  end

  # Only allow a list of trusted parameters through.
  def user_params
    # last_login_at is server-set (auth flow) — never accept it from the client.
    params.require(:user).permit(:name, :email, :role)
  end

  # Role for an invited user. Defaults to :member; only a valid enum value is
  # accepted so an admin can choose to invite another admin. Validated against
  # AccountMembership, which is where the role actually lands.
  def invited_role
    AccountMembership.roles.key?(params[:role].to_s) ? params[:role] : :member
  end

  def demoting_last_admin?
    return false unless user_params[:role].to_s == "member"
    last_account_admin?(@user)
  end

  # True when `user` currently has admin access to this workspace and nobody else
  # in it does, so demoting/removing them would lock everyone out. Counts admin
  # *memberships* of this workspace (plus platform super admins, who retain
  # access regardless of role).
  def last_account_admin?(user)
    return false unless user.account_admin?(@account)
    # Accepted only: an outstanding admin *invitation* is not cover for demoting
    # the last real one — nobody could administer the workspace until they accept.
    !AccountMembership.accepted
                      .joins(:user)
                      .where(account_id: @account.id)
                      .where.not(user_id: user.id)
                      .where("account_memberships.role = :admin OR users.is_super_admin = :yes",
                             admin: AccountMembership.roles[:admin], yes: true)
                      .exists?
  end

  def generate_jwt(user)
    JWT.encode({ id: user.id, exp: 24.hours.from_now.to_i }, Rails.application.secret_key_base)
  end
end
