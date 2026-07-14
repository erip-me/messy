class UsersController < ApplicationController
  before_action :authenticate_user!, except: [:me]
  before_action :set_account, except: [:me]
  before_action :require_account_admin!, only: %i[create update destroy]
  before_action :set_user, only: %i[show update destroy]

  # GET /users
  def index
    @users = @account.users.includes(operator_profile: { avatar_attachment: :blob })
    render json: UserResource.new(@users).serialize
  end

  # GET /users/1
  def show
    render json: UserResource.new(@user).serialize
  end

  # POST /users
  def create
    @user = @account.users.new(
      name: params[:name],
      email: params[:email],
      role: invited_role
    )

    if @user.save
      @user.generate_magic_link_token!
      UserMailer.with(user: @user, inviter: current_user).invitation_email.deliver_later
      render json: UserResource.new(@user).serialize, status: :created
    else
      render json: { message: @user.errors.full_messages.join(', ') }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /users/1
  def update
    if demoting_last_admin?
      return render json: { message: "You can't remove the last admin of the account" }, status: :unprocessable_entity
    end

    if @user.update(user_params)
      render json: UserResource.new(@user).serialize
    else
      render json: @user.errors, status: :unprocessable_entity
    end
  end

  # DELETE /users/1
  def destroy
    if last_account_admin?(@user)
      return render json: { message: "You can't delete the last admin of the account" }, status: :unprocessable_entity
    end

    @user.destroy!
  end

  def me
    authenticate_user!
    return unless current_user

    render json: { user: UserResource.new(current_user).to_h, token: generate_jwt(current_user) }, status: :ok
  end

  private

  def set_account
    @account = current_user.account
  end

  def set_user
    @user = @account.users.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def user_params
    # last_login_at is server-set (auth flow) — never accept it from the client.
    params.require(:user).permit(:name, :email, :role)
  end

  # Role for an invited user. Defaults to :member; only a valid enum value is
  # accepted so an admin can choose to invite another admin.
  def invited_role
    User.roles.key?(params[:role].to_s) ? params[:role] : :member
  end

  def demoting_last_admin?
    return false unless user_params[:role].to_s == "member"
    last_account_admin?(@user)
  end

  # True when `user` currently has account-admin access and no other user in the
  # account does, so demoting/deleting them would lock everyone out.
  def last_account_admin?(user)
    return false unless user.account_admin?
    !@account.users.where.not(id: user.id)
                   .where("role = :admin OR is_super_admin = :yes", admin: User.roles[:admin], yes: true)
                   .exists?
  end

  def generate_jwt(user)
    JWT.encode({ id: user.id, exp: 24.hours.from_now.to_i }, Rails.application.secret_key_base)
  end
end
