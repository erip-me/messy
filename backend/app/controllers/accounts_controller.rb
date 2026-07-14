class AccountsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_account
  before_action :require_account_admin!, only: %i[update onboarding]

  # GET /accounts
  def index
    render json: AccountResource.new(@account).serialize
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
      @account = current_user.account
    end

    def account_params
      params.require(:account).permit(:name, :tracking_domain, :message_retention_days)
    end
end
