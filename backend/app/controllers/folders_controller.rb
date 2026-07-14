class FoldersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_account
  before_action :set_environment
  before_action :set_folder, only: [:show, :update, :destroy, :move]

  # GET /folders
  def index
    @folders = @environment.folders.active.includes(:child_folders, :templates)
    render json: FolderListResource.new(@folders).serialize
  end

  # GET /folders/1
  def show
    render json: FolderWithContentsResource.new(@folder).serialize
  end

  # POST /folders
  def create
    @folder = @environment.folders.build(folder_params)
    @folder.account = current_user.account

    if @folder.parent_folder_id.present?
      unless @environment.folders.active.exists?(id: @folder.parent_folder_id)
        return render json: { error: "Parent folder not found" }, status: :unprocessable_entity
      end
    end

    if @folder.save
      render json: FolderResource.new(@folder).serialize, status: :created
    else
      render json: @folder.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /folders/1
  def update
    safe_params = folder_params
    if safe_params[:parent_folder_id].present?
      unless @environment.folders.active.exists?(id: safe_params[:parent_folder_id])
        return render json: { error: "Parent folder not found" }, status: :unprocessable_entity
      end
    end

    if @folder.update(safe_params)
      render json: FolderResource.new(@folder).serialize
    else
      render json: @folder.errors, status: :unprocessable_entity
    end
  end

  # DELETE /folders/1
  def destroy
    @folder.update(is_deleted: true)
    head :no_content
  end

  # POST /folders/1/move
  def move
    target_folder_id = params[:target_folder_id]
    
    # Validate target folder exists and belongs to same environment
    if target_folder_id.present?
      target_folder = @environment.folders.active.find(target_folder_id)
      
      # Prevent circular reference
      if target_folder.path.include?(@folder)
        render json: { error: 'Cannot move folder into its own subfolder' }, status: :unprocessable_entity
        return
      end
      
      @folder.parent_folder = target_folder
    else
      @folder.parent_folder = nil
    end

    if @folder.save
      render json: FolderResource.new(@folder).serialize
    else
      render json: @folder.errors, status: :unprocessable_entity
    end
  end

  private

  def set_account
    @account = current_user.account
  end

  def set_folder
    @folder = @account.folders.active.find(params[:id])
  end

  def set_environment
    if params[:environment_id]
      @environment = @account.environments.find(params[:environment_id])
    else
      env_id = request.headers['X-Environment-Id']
      @environment = env_id.present? ? @account.environments.find_by(id: env_id) : nil
      @environment ||= @account.environments.first
    end
  end

  def folder_params
    params.require(:folder).permit(:name, :parent_folder_id)
  end

end