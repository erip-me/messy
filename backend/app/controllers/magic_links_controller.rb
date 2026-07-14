class MagicLinksController < ApplicationController
  include ::ActionController::Cookies

  GENERIC_MAGIC_LINK_RESPONSE = "If an account with that email exists, you will receive a magic link.".freeze

  def create
    @var = JSON.parse!(request.raw_post)
    email = @var["email"].to_s.strip.downcase
    # Look up only — never create a user here (that's the /signup flow). Creating
    # users on this public endpoint enables unauthenticated account seeding.
    user = User.find_by(email: email)

    if user
      user.generate_magic_link_token!

      if Rails.env.development?
        # Dev mode: skip email, return token directly for instant login
        return render json: {
          message: "Dev mode: use the token below to login",
          token: user.magic_link_token,
          login_url: "#{ENV.fetch('FRONTEND_URL', request.base_url)}/validate/#{user.magic_link_token}"
        }, status: :ok
      end

      UserMailer.with(user: user).magic_link.deliver_now
    end

    # Always return the same response whether or not the email exists, so the
    # endpoint can't be used to enumerate registered accounts.
    render json: { message: GENERIC_MAGIC_LINK_RESPONSE }, status: :ok
  end

  def validate
    user = User.find_by(magic_link_token: params[:token])

    if user&.magic_link_token_valid?
      user.reset_magic_link_token!
      user.update_columns(last_login_at: Time.current, email_verified: true)

      # Activate account if it was awaiting email verification
      account = user.account
      if account&.pending_verification?
        account.update_column(:status, 'active')
      end

      session[:user_id] = user.id
      render json: { token: generate_jwt(user), user: user, account: account }, status: :ok
    else
      render json: { error: 'Invalid or expired magic link' }, status: :unauthorized
    end
  end

  def destroy
    reset_session
    render json: { message: 'Logged out' }, status: :ok
  end

  private

  def generate_jwt(user)
    JWT.encode({ id: user.id, exp: 24.hours.from_now.to_i }, Rails.application.secret_key_base)
  end
end
