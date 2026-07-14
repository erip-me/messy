class ConversationTagsController < ApplicationController
  include ApiAuthentication

  def index
    tags = @account.conversation_tags.ordered
    render json: { tags: ConversationTagResource.new(tags).to_h }
  end

  def create
    tag = @account.conversation_tags.create!(tag_params)
    render json: { tag: ConversationTagResource.new(tag).to_h }, status: :created
  end

  def update
    tag = @account.conversation_tags.find(params[:id])
    tag.update!(tag_params)
    render json: { tag: ConversationTagResource.new(tag).to_h }
  end

  def destroy
    tag = @account.conversation_tags.find(params[:id])
    tag.destroy!
    head :no_content
  end

  private

  def tag_params
    params.permit(:name, :is_quick_reply, :sort_order)
  end

end
