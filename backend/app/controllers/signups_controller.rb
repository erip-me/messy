class SignupsController < ApplicationController
  # Public endpoint — no authentication required (before_action not set)

  TURNSTILE_VERIFY_URL = 'https://challenges.cloudflare.com/turnstile/v0/siteverify'.freeze

  def create
    email        = params[:email]&.strip&.downcase
    name         = params[:name]&.strip
    account_name = params[:account_name]&.strip

    unless turnstile_valid?
      return render json: { error: 'Captcha verification failed. Please reload the page and try again.' }, status: :unprocessable_entity
    end

    if [email, name, account_name].any?(&:blank?)
      return render json: { error: 'Name, email, and account name are required' }, status: :unprocessable_entity
    end

    if User.exists?(email: email)
      return render json: { error: 'An account with this email already exists. Please sign in instead.' }, status: :conflict
    end

    ActiveRecord::Base.transaction do
      account = Account.create!(name: account_name, plan: 'trial', trial_ends_at: 14.days.from_now, status: 'pending_verification')
      # The signing-up user owns the new account, so they are its first admin.
      user    = User.create!(account: account, name: name, email: email, role: :admin)
      user.generate_magic_link_token!

      Analytics.track("account_signed_up", account: account, user: user,
                      properties: { plan: account.plan })

      ContactMailer.with(user: user).new_signup.deliver_later

      if Rails.env.development?
        render json: {
          message: 'Dev mode: use this token to verify your email',
          token: user.magic_link_token,
          verify_url: "#{ENV.fetch('FRONTEND_URL', request.base_url)}/validate/#{user.magic_link_token}"
        }, status: :created
      else
        UserMailer.with(user: user).verification_email.deliver_later
        render json: { message: 'Account created! Check your email to verify your address.' }, status: :created
      end
    end
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.join(', ') }, status: :unprocessable_entity
  end

  private

  # No-op unless TURNSTILE_SECRET_KEY is set (dev/test/OSS installs).
  # Fails closed on Cloudflare errors: better to briefly block signups than let bots through.
  def turnstile_valid?
    secret = ENV['TURNSTILE_SECRET_KEY']
    return true if secret.blank?

    res = Net::HTTP.post_form(URI(TURNSTILE_VERIFY_URL),
                              secret: secret,
                              response: params[:turnstile_token].to_s,
                              remoteip: request.remote_ip)
    JSON.parse(res.body)['success'] == true
  rescue StandardError => e
    Rails.logger.error("Turnstile verification error: #{e.message}")
    false
  end
end
