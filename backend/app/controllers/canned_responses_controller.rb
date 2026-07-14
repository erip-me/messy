class CannedResponsesController < ApplicationController
  include ApiAuthentication

  def index
    responses = @account.canned_responses
    responses = responses.search(params[:q]) if params[:q].present?
    render json: { canned_responses: CannedResponseResource.new(responses).to_h }
  end

  def create
    response = @account.canned_responses.create!(response_params.merge(created_by: current_user))
    render json: { canned_response: CannedResponseResource.new(response).to_h }, status: :created
  end

  def update
    response = @account.canned_responses.find(params[:id])
    response.update!(response_params)
    render json: { canned_response: CannedResponseResource.new(response).to_h }
  end

  def destroy
    response = @account.canned_responses.find(params[:id])
    response.destroy!
    head :no_content
  end

  private

  def response_params
    params.permit(:shortcut, :title, :content)
  end

end
