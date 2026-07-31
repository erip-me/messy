class AccountsController < ApplicationController
  before_action :authenticate_user!
  # accept/decline act on a workspace the caller is NOT yet a member of, so they
  # can't resolve one the normal way — they find their own pending row instead.
  before_action :set_account, except: %i[create accept_invitation decline_invitation]
  before_action :require_account_admin!, only: %i[update onboarding]

  # GET /accounts
  def index
    render json: AccountResource.new(@account).serialize
  end

  # POST /accounts — create an additional workspace for the signed-in user.
  #
  # The unauthenticated /signup path still refuses an email that already exists
  # (one login per person); this is how someone who already has a login gets a
  # second workspace. They become its first admin, so no invite is involved and
  # nobody else's workspace is touched.
  def create
    account = nil

    ActiveRecord::Base.transaction do
      account = Account.create!(
        name: params.require(:name),
        plan: 'trial',
        trial_ends_at: 14.days.from_now,
        # Already an authenticated, verified user — nothing to verify, and no
        # first-run onboarding to repeat. Without onboarding_completed_at the SPA's
        # ProtectedRoute would bounce them into the signup wizard on switch.
        status: 'active',
        onboarding_completed_at: Time.current
      )
      # Accepted outright — they made it, so there is nothing to consent to.
      AccountMembership.create!(user: current_user, account: account, role: :admin,
                                accepted_at: Time.current)

      # Everything below the workspace is environment-scoped, and nothing else in
      # the app creates an environment (the onboarding wizard only covers invites
      # and plan choice). Without this the switcher drops you into a workspace
      # where every page is empty and no request carries an X-Environment-Id.
      account.environments.create!(name: 'Production', tag: 'prod')
    end

    render json: AccountResource.new(account).serialize, status: :created
  end

  # POST /accounts/:id/accept_invitation
  #
  # The consent step: the only thing that turns an invitation into access.
  # Scoped to the caller's own pending row, so it can neither accept on someone
  # else's behalf nor conjure a membership that was never offered.
  def accept_invitation
    membership = pending_invitation
    return render json: { error: 'No pending invitation for that workspace' }, status: :not_found unless membership

    membership.update!(accepted_at: Time.current)
    render json: AccountResource.new(membership.account).serialize
  end

  # DELETE /accounts/:id/decline_invitation
  def decline_invitation
    membership = pending_invitation
    return render json: { error: 'No pending invitation for that workspace' }, status: :not_found unless membership

    membership.destroy!
    head :no_content
  end

  # GET /accounts/1
  def show
    render json: AccountResource.new(@account).serialize
  end

  # PATCH/PUT /accounts/1
  def update
    if @account.update(account_params)
      render json: AccountResource.new(@account).serialize
    else
      render json: @account.errors, status: :unprocessable_entity
    end
  end

  # PATCH /accounts/:id/onboarding
  def onboarding
    step      = params[:step].to_i
    completed = params[:completed]

    updates = { onboarding_step: step }
    is_completing = (completed == true || completed == 'true') && @account.onboarding_completed_at.blank?
    updates[:onboarding_completed_at] = Time.current if completed == true || completed == 'true'

    if @account.update(updates)
      Analytics.track("onboarding_completed", account: @account, user: current_user) if is_completing
      render json: AccountResource.new(@account).serialize
    else
      render json: @account.errors, status: :unprocessable_entity
    end
  end

  private

    def set_account
      @account = resolved_account
    end

    def pending_invitation
      current_user.account_memberships.pending.find_by(account_id: params[:id])
    end

    def account_params
      params.require(:account).permit(:name, :tracking_domain, :message_retention_days)
    end
end
