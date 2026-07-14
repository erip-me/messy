class CustomerIdentifyController < ApplicationController
  include ApiAuthentication

  # POST /customers/identify
  def identify
    unless params[:email].present?
      return render json: { error: "email is required" }, status: :unprocessable_entity
    end

    customer = @account.customers.find_or_initialize_by(email: params[:email].downcase.strip)

    customer.first_name = params[:first_name] if params[:first_name].present?
    customer.last_name = params[:last_name] if params[:last_name].present?

    if params[:custom_attributes].is_a?(ActionController::Parameters)
      permitted_attrs = params[:custom_attributes].permit(params[:custom_attributes].keys).to_h
      customer.custom_attributes = (customer.custom_attributes || {}).merge(permitted_attrs)
    elsif params[:custom_attributes].is_a?(Hash)
      customer.custom_attributes = (customer.custom_attributes || {}).merge(params[:custom_attributes].slice(*params[:custom_attributes].keys))
    end

    customer.save!
    membership_dirty = customer.id_previously_changed? ||
                       customer.saved_change_to_custom_attributes? ||
                       customer.saved_change_to_first_name? ||
                       customer.saved_change_to_last_name?
    customer.touch_last_seen
    customer.reload

    RecomputeSegmentMembershipsJob.perform_later(customer.id) if membership_dirty

    recent = @account.customer_activities
      .where(customer: customer, environment: @environment, activity_type: "identify")
      .where("created_at > ?", 5.minutes.ago)
      .exists?

    unless recent
      CustomerActivity.create!(
        account: @account,
        customer: customer,
        environment: @environment,
        activity_type: "identify",
        properties: {
          ip_address: request.remote_ip,
          user_agent: request.user_agent
        }
      )
    end

    render json: {
      customer: {
        id: customer.id,
        email: customer.email,
        first_name: customer.first_name,
        last_name: customer.last_name,
        custom_attributes: customer.custom_attributes,
        last_seen_at: customer.last_seen_at,
        created_at: customer.created_at
      }
    }
  end
end
