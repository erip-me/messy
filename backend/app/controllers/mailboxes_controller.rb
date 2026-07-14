class MailboxesController < ApplicationController
  include ApiAuthentication

  before_action :find_mailbox, only: [:show, :update, :destroy, :test_connection, :oauth_url]
  rescue_from ActiveRecord::RecordNotFound, with: :render_404

  def index
    mailboxes = @account.mailboxes.includes(:environment)
    render json: { mailboxes: mailboxes.map { |m| MailboxResource.new(m).to_h } }
  end

  def show
    render json: { mailbox: MailboxResource.new(@mailbox).to_h }
  end

  def create
    mailbox = @account.mailboxes.new(mailbox_params)
    mailbox.environment = @environment
    mailbox.save!
    render json: { mailbox: MailboxResource.new(mailbox).to_h }, status: :created
  end

  def update
    @mailbox.update!(mailbox_params)
    render json: { mailbox: MailboxResource.new(@mailbox).to_h }
  end

  def destroy
    @mailbox.destroy!
    head :no_content
  end

  def test_connection
    fetcher = @mailbox.fetcher
    result = fetcher.test_connection!
    render json: { success: true, details: result }
  rescue => e
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end

  # Returns the provider consent URL to redirect the user to. State is a signed
  # JWT so the (unauthenticated) OAuth callback can trust which mailbox it's for.
  def oauth_url
    provider = @mailbox.provider

    unless @mailbox.oauth?
      return render json: { error: "#{provider} mailboxes are not connected via OAuth" }, status: :unprocessable_entity
    end

    mod = provider == "gmail" ? MailboxOauth::Google : MailboxOauth::Microsoft
    unless mod.configured?
      return render json: { error: "#{provider} OAuth is not configured on this server" }, status: :unprocessable_entity
    end

    state = JWT.encode(
      { mailbox_id: @mailbox.id, exp: 15.minutes.from_now.to_i },
      Rails.application.secret_key_base,
      "HS256"
    )
    render json: { url: mod.authorize_url(state) }
  end

  private

  def find_mailbox
    @mailbox = @account.mailboxes.find(params[:id])
  end

  def mailbox_params
    params.permit(
      :name, :email_address, :provider, :ticket_prefix,
      :auto_assign, :auto_reply_enabled, :auto_reply_template,
      :auto_close_days, :active,
      config: {}, notification_events: {}
    )
  end

end
