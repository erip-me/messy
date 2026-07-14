module Widget
  class IdentityController < BaseController
    def identify
      unless params[:email].present?
        return render json: { error: "Email is required" }, status: :unprocessable_entity
      end

      unless identity_verified?
        return render json: { error: "Identity verification failed" }, status: :forbidden
      end

      anonymous_customer = Customer.find_by(account: @account, anonymous_token: @visitor_token)
      existing_customer = Customer.find_by(account: @account, email: params[:email])

      if existing_customer && anonymous_customer && existing_customer.id != anonymous_customer.id
        # Merge: move conversations from anonymous to identified customer
        Conversation.where(account: @account, customer: anonymous_customer)
                    .update_all(customer_id: existing_customer.id)
        Conversation.where(account: @account, visitor_token: @visitor_token)
                    .update_all(customer_id: existing_customer.id)

        anonymous_customer.destroy!
        existing_customer.update!(anonymous_token: @visitor_token)
        @customer = existing_customer
      elsif existing_customer
        # Already identified, just link the visitor token
        existing_customer.update!(anonymous_token: @visitor_token)
        @customer = existing_customer
      elsif anonymous_customer
        # Update anonymous customer with real identity
        anonymous_customer.update!(
          email: params[:email],
          first_name: params[:first_name] || anonymous_customer.first_name,
          last_name: params[:last_name],
          custom_attributes: anonymous_customer.custom_attributes.merge(params[:custom_attributes] || {})
        )
        # Update conversation visitor names
        Conversation.where(account: @account, visitor_token: @visitor_token)
                    .update_all(
                      visitor_name: [params[:first_name], params[:last_name]].compact.join(" ").presence,
                      visitor_email: params[:email]
                    )
        @customer = anonymous_customer
      else
        # Create new identified customer
        @customer = Customer.create!(
          account: @account,
          anonymous_token: @visitor_token,
          email: params[:email],
          first_name: params[:first_name],
          last_name: params[:last_name],
          custom_attributes: params[:custom_attributes] || {},
          last_seen_at: Time.current
        )
      end

      render json: {
        customer: {
          id: @customer.id,
          email: @customer.email,
          first_name: @customer.first_name,
          last_name: @customer.last_name
        }
      }
    end

    private

    # Opt-in identity verification (Intercom-style). When the widget has an
    # identity_verification_secret configured, the embedding site must sign the
    # email with HMAC-SHA256 and send it as `user_hash`; an unsigned or forged
    # call is rejected so it can't claim/overwrite another customer's identity.
    # When no secret is configured, behaviour is unchanged (trusts the caller).
    def identity_verified?
      secret = @widget_settings&.identity_verification_secret
      return true if secret.blank?

      provided = params[:user_hash].to_s
      return false if provided.blank?

      expected = OpenSSL::HMAC.hexdigest("SHA256", secret, params[:email].to_s)
      ActiveSupport::SecurityUtils.secure_compare(expected, provided)
    end
  end
end
