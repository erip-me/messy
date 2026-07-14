class SuperAdmin::AccountsController < SuperAdmin::BaseController
  before_action :set_account, only: [:show, :update, :destroy]

  # GET /admin/accounts
  def index
    @accounts = Account.includes(:users).all
    @accounts = @accounts.page(params[:page]).per(params[:per_page] || 25)
    
    render json: {
      accounts: SuperAdmin::AccountResource.new(@accounts).to_h,
      meta: pagination_meta(@accounts)
    }
  end

  # GET /admin/accounts/1
  def show
    account_data = SuperAdmin::AccountDetailResource.new(@account).to_h

    # Add stats
    account_data[:stats] = {
      total_users: @account.users.count,
      total_environments: @account.environments.count,
      total_templates: @account.templates.count,
      total_messages: @account.messages.count,
      messages_last_30_days: @account.messages.where('created_at > ?', 30.days.ago).count
    }

    render json: account_data
  end

  # POST /admin/accounts
  def create
    @account = Account.new(account_params)

    if @account.save
      # Create first user if provided
      if params[:first_user].present?
        user_params = params[:first_user].permit(:name, :email)
        @user = @account.users.create!(user_params)
      end
      
      render json: SuperAdmin::AccountResource.new(@account).serialize, status: :created
    else
      render json: @account.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /admin/accounts/1
  def update
    if @account.update(account_params)
      render json: SuperAdmin::AccountResource.new(@account).serialize
    else
      render json: @account.errors, status: :unprocessable_entity
    end
  end

  # DELETE /admin/accounts/1
  def destroy
    @account.destroy
    head :no_content
  end

  private

  def set_account
    @account = Account.find(params[:id])
  end

  def account_params
    params.require(:account).permit(:name, :plan, :trial_ends_at, :payment_status)
  end

  def pagination_meta(collection)
    {
      current_page: collection.current_page,
      total_pages: collection.total_pages,
      total_count: collection.total_count,
      per_page: collection.limit_value
    }
  end
end