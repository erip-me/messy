class SuperAdmin::UsersController < SuperAdmin::BaseController
  before_action :set_user, only: [:show, :update, :destroy]

  # GET /admin/users
  def index
    @users = User.includes(:account).all
    
    # Filter by account if provided
    @users = @users.where(account_id: params[:account_id]) if params[:account_id].present?
    
    @users = @users.page(params[:page]).per(params[:per_page] || 25)
    
    render json: {
      users: SuperAdmin::UserResource.new(@users).to_h,
      meta: pagination_meta(@users)
    }
  end

  # GET /admin/users/1
  def show
    user_data = SuperAdmin::UserDetailResource.new(@user).to_h

    # Add activity stats
    user_data[:stats] = {
      total_messages_sent: @user.account.messages.count,
      templates_created: @user.account.templates.count,
      last_activity: @user.last_login_at
    }

    render json: user_data
  end

  # POST /admin/users
  def create
    @user = User.new(user_params)

    if @user.save
      render json: SuperAdmin::UserResource.new(@user).serialize, status: :created
    else
      render json: @user.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /admin/users/1
  def update
    if @user.update(user_params)
      render json: SuperAdmin::UserResource.new(@user).serialize
    else
      render json: @user.errors, status: :unprocessable_entity
    end
  end

  # DELETE /admin/users/1
  def destroy
    @user.destroy
    head :no_content
  end

  # POST /admin/users/1/toggle_super_admin
  def toggle_super_admin
    @user = User.find(params[:id])
    @user.update!(is_super_admin: !@user.is_super_admin)

    render json: SuperAdmin::UserResource.new(@user).serialize
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:name, :email, :account_id, :is_super_admin)
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