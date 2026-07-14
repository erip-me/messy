class MessagesController < ApplicationController
  include ApiAuthentication

  before_action :load_message, only: %i[ show update destroy retry_delivery attachment ]
  before_action :validate_type_param, only: %i[ create ]
  before_action :load_template_by_trigger, only: %i[ trigger ]
  before_action :require_active_billing!, only: %i[ create trigger ]

  # GET /messages
  def index
    base = if @environment
             @environment.messages
           elsif @account
             Message.where(account_id: @account.id)
           else
             Message.none
           end

    base = base.where("messages.\"to\" ILIKE :q OR messages.subject ILIKE :q", q: "%#{params[:search]}%") if params[:search].present?
    base = base.where(type: "#{params[:channel].capitalize}Message") if params[:channel].present?
    base = base.where(status: params[:status]) if params[:status].present?
    if params[:date_from].present?
      from = parse_filter_date(params[:date_from])
      return render json: { error: "Invalid date_from: #{params[:date_from]}. Use YYYY-MM-DD or an ISO 8601 timestamp." }, status: :unprocessable_entity if from.nil?
      base = base.where("messages.created_at >= ?", from.beginning_of_day)
    end
    if params[:date_to].present?
      to = parse_filter_date(params[:date_to])
      return render json: { error: "Invalid date_to: #{params[:date_to]}. Use YYYY-MM-DD or an ISO 8601 timestamp." }, status: :unprocessable_entity if to.nil?
      base = base.where("messages.created_at <= ?", to.end_of_day)
    end
    base = base.where(drip_campaign_id: params[:drip_id]) if params[:drip_id].present?
    base = base.where(drip_step_id: params[:drip_step_id]) if params[:drip_step_id].present?

    @messages = base.where(parent_message_id: nil)
                    .includes(:environment)
                    .order(created_at: :desc)
                    .page(params[:page])
                    .per(params[:per_page])

    render json: {
      data: MessageListResource.new(@messages).to_h,
      meta: {
        current_page: @messages.current_page,
        total_pages: @messages.total_pages,
        total_count: @messages.total_count
      }
    }
  end

  # GET /messages/1
  def show
    primary_email = begin
      Mail::AddressList.new(@message.to).addresses.first&.address&.downcase
    rescue
      nil
    end
    customer = primary_email && @account&.customers&.find_by(email: primary_email)

    attachments = @message.attachments.map do |a|
      {
        id: a.id,
        filename: a.filename.to_s,
        content_type: a.content_type,
        byte_size: a.byte_size,
        url: "#{request.base_url}/messages/#{@message.id}/attachments/#{a.id}"
      }
    end

    render json: MessageDetailResource.new(@message).to_h.merge(
      template_name: @message.template&.name,
      sending_identity: @message.sending_identity&.slice(:id, :from_name, :from_email),
      drip: drip_info(@message),
      customer: customer ? { id: customer.id, email: customer.email, first_name: customer.first_name, last_name: customer.last_name, unsubscribed_channels: customer.unsubscribed_channels } : nil,
      attachments: attachments,
      link_clicks: @message.link_click_counts.map { |url, count| { url: url, count: count } }
    )
  end

  # POST /messages
  def create
    process_built_message(build_message)
  end

  # POST /trigger
  def trigger
    message_class = case @template.channel
                    when "sms" then SmsMessage
                    when "whatsapp" then WhatsappMessage
                    when "push" then MobilePushMessage
                    else EmailMessage
                    end

    message = message_class.build_from(message_params, @template)

    # Auto-provided merge tags the caller never has to fill: a real per-message
    # unsubscribe link (needs the tracking token generated up front so it resolves).
    message.generate_tracking_token
    auto_vars = { "unsubscribe_url" => unsubscribe_url_for(message) }

    tags_present_in_params?(message, provided: auto_vars.keys)

    h = if params[:data].is_a?(ActionController::Parameters)
          params[:data].permit(params[:data].keys).to_h
        else
          {}
        end
    # Auto vars win over any value the caller passed for the same key.
    vars = h.merge(auto_vars)
    rendered = TemplateRenderer.call(template: @template, variables: vars)
    message.subject = rendered.subject if message.subject.present?
    message.body = rendered.body

    # Store the caller-provided trigger data for visibility in the UI.
    message.tags = [{ "trigger_data" => h }] if h.present?

    process_built_message(message)
  end

  # PATCH/PUT /messages/1
  def update
    unless @message.pending? || @message.draft?
      return render json: { error: "Only pending or draft messages can be edited" }, status: :unprocessable_entity
    end

    if @message.update(message_params)
      ActionCable.server.broadcast "messages_channel_#{@message.account_id}", message: @message

      render json: MessageResource.new(@message).serialize
    else
      render json: @message.errors, status: :unprocessable_entity
    end
  end

  # DELETE /messages/1
  def destroy
    account_id = @message.account_id
    @message.destroy!

    ActionCable.server.broadcast "messages_channel_#{account_id}", message: { id: @message.id, deleted: true }
  end

  # POST /messages/1/retry
  def retry_delivery
    unless @message.failed? || @message.expired? || @message.rejected? || @message.suppressed?
      return render json: { error: "Only failed, expired, rejected, or suppressed messages can be retried" }, status: :unprocessable_entity
    end

    retryable_children = @message.child_messages.where(status: [:failed, :expired, :rejected, :suppressed])

    if retryable_children.any?
      retryable_children.each do |child|
        child.update!(status: :pending)
        DeliverMessageJob.perform_later child, force: true
      end
    else
      DeliverMessageJob.perform_later @message, force: true
    end

    @message.update!(status: :pending)

    render json: MessageDetailResource.new(@message.reload).serialize
  end

  # GET /messages/:id/attachments/:attachment_id
  def attachment
    blob = @message.attachments.find_by(id: params[:attachment_id])&.blob
    return head :not_found unless blob

    send_data blob.download,
      filename: blob.filename.to_s,
      type: blob.content_type,
      disposition: params[:download] ? "attachment" : "inline"
  end

  private
    # Parses a date filter value (YYYY-MM-DD or an ISO 8601 timestamp), returning
    # nil on anything unparseable so the caller can respond 422 rather than raise.
    def parse_filter_date(value)
      value.to_date
    rescue ArgumentError, TypeError
      nil
    end

    def drip_info(message)
      return nil unless message.drip_campaign_id

      drip = DripCampaign.find_by(id: message.drip_campaign_id)
      return nil unless drip

      {
        id: drip.id,
        name: drip.name,
        step_position: message.drip_step&.position
      }
    end

    def validate_type_param
      valid_types = Integration.kinds.keys
      unless valid_types.include?(params[:type])
        render json: { error: "Invalid message type" }, status: :unprocessable_entity
      end
    end

    def build_message
      case params[:type]
      when 'email'
        return EmailMessage.new(message_params)
      when 'sms'
        return SmsMessage.new(message_params)
      when 'whatsapp'
        return WhatsappMessage.new(message_params)
      when 'mobile_push'
        return MobilePushMessage.new(message_params)
      when 'web_push'
        return WebPushMessage.new(message_params)
      else
        raise "Invalid type #{params[:type]}"
      end
    end

    def process_built_message(message)
      message.account = @account
      message.environment = @environment
      message.status = :pending

      if message.save
        ProcessMessageJob.perform_now message

        render json: MessageResource.new(message).serialize, status: :created, location: "/messages/#{message.id}"
      else
        render json: message.errors, status: :unprocessable_entity
      end
    end

    # Public unsubscribe link for a transactional/triggered message, resolved by
    # the recipient + channel of the message (see TrackingController#unsubscribe).
    def unsubscribe_url_for(message)
      "#{@account.tracking_base_url}/track/#{message.tracking_token}/unsubscribe"
    end

    def tags_present_in_params?(message, provided: [])
      # Parse the template to extract variable tags
      template = Liquid::Template.parse(message.body)
      variables = template.root.nodelist.select { |node| node.is_a?(Liquid::Variable) }.map(&:name)

      # Tags the server fills in automatically don't need to be supplied by the caller.
      required = variables.reject { |tag| provided.include?(tag.name) }

      if required.any?
        raise "Missing template data" unless params[:data]

        # Check if all variables (tags) are present as keys in the params hash
        required.all? do |tag|
          unless params[:data].key?(tag.name)
            raise "Missing template data for key #{tag.name}"
          end
        end
      end
    end

    # Only allow a list of trusted parameters through.
    def message_params
      permitted = params.require(:message).permit(:to, :cc, :bcc, :subject, :body, :language, :sending_identity_id, attachments: [])
      if params[:message][:tags].present?
        tags = params[:message][:tags]
        if tags.is_a?(Array)
          # Tags can be simple strings (flat body params) or component hashes
          # (WhatsApp template components like {type: "body", parameters: [...]}).
          # Accept both forms so the WhatsApp integration can use them directly.
          permitted[:tags] = tags.map { |t|
            t.is_a?(ActionController::Parameters) || t.is_a?(Hash) ? t.to_unsafe_h : t.to_s
          }
        end
      end
      permitted
    end
end