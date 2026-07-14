# Sends a single drip step as a transactional message. Renders the step's
# template with Liquid (same variable set as campaign delivery), tags the
# message with its drip/step so the rest of the app can show "sent via drip",
# and hands off to the existing transactional pipeline (ProcessMessageJob,
# which applies rules and channel suppression).
#
# Returns a Result whose status is one of:
#   "sent"       - a message was created and queued
#   "suppressed" - customer is unsubscribed from the channel; nothing sent
#   "failed"     - the step is not sendable (e.g. no template)
class DripStepSender
  Result = Struct.new(:status, :message, :reason, keyword_init: true)

  MESSAGE_CLASSES = {
    "email" => "EmailMessage",
    "sms" => "SmsMessage",
    "whatsapp" => "WhatsappMessage",
    "push" => "MobilePushMessage"
  }.freeze

  def self.call(enrollment, step)
    new(enrollment, step).call
  end

  def initialize(enrollment, step)
    @enrollment = enrollment
    @drip = enrollment.drip_campaign
    @customer = enrollment.customer
    @step = step
  end

  def call
    template = @step.template
    return Result.new(status: "failed", reason: "no template") unless template

    channel = @step.channel.presence || template.channel
    # Drips are marketing: suppressed by a hard channel block OR a marketing opt-out
    # (but a marketing opt-out never blocks transactional/system messages elsewhere).
    if @customer.suppressed_for?(channel: channel, category: Customer::MARKETING_CATEGORY)
      return Result.new(status: "suppressed", reason: "unsubscribed (#{channel}/marketing)")
    end

    to = @customer.address_for(channel)
    return Result.new(status: "failed", reason: "customer has no #{channel} address") if to.blank?

    message = message_class(channel).new(
      account: @drip.account,
      environment: @drip.environment,
      template: template,
      drip_campaign_id: @drip.id,
      drip_step_id: @step.id,
      sending_identity_id: @drip.sending_identity_id,
      to: to,
      status: :pending
    )
    # Generate the tracking token up front so {{unsubscribe_url}} can reference it.
    message.generate_tracking_token

    vars = @customer.liquid_variables.merge("unsubscribe_url" => unsubscribe_url(message))
    rendered = TemplateRenderer.call(template: template, variables: vars)
    message.subject = rendered.subject if template.subject.present?
    message.body = rendered.body

    message.save!
    ProcessMessageJob.perform_later(message)

    Result.new(status: "sent", message: message)
  end

  private

  def unsubscribe_url(message)
    "#{@drip.account.tracking_base_url}/track/#{message.tracking_token}/unsubscribe"
  end

  def message_class(channel)
    (MESSAGE_CLASSES[channel] || "EmailMessage").constantize
  end
end
