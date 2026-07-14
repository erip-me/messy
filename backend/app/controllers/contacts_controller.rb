# Public, unauthenticated. Reached by the marketing site's contact and
# enterprise forms (a static export on Cloudflare Pages, so it has no server of
# its own). Abuse control: Rack::Attack throttle + honeypot. Nothing is
# persisted; the enquiry is emailed to the sales inbox.
#
# ponytail: no Contact model. Email is the deliverable and the inbox is the
# system of record. Add a table when someone wants a lead pipeline.
class ContactsController < ApplicationController
  REQUIRED = %i[name email message].freeze
  # The enterprise wizard leaves both free-text answers optional; who they are and
  # what they're after (a required select on the client) is enough to reply.
  ENTERPRISE_REQUIRED = %i[name email company].freeze

  # Every accepted field, with its max length. Anything else the client sends is
  # dropped rather than forwarded into an email we then have to trust. The
  # enterprise questionnaire fills in more of these than the contact form does.
  LIMITS = {
    name: 100, email: 255, company: 100, role: 100, company_size: 50,
    current_stack: 500, monthly_volume: 50, interest: 100, timeline: 50,
    goals: 5_000, message: 5_000
  }.freeze

  MAX_CHANNELS = 10

  def create
    # Honeypot: a real browser leaves this hidden field empty, bots fill it in.
    # Answer 201 either way so a bot learns nothing from the response.
    return render(json: { ok: true }, status: :created) if params[:website].present?

    contact = LIMITS.keys.index_with { |k| params[k].to_s.strip }
    contact[:channels] = Array(params[:channels]).first(MAX_CHANNELS).map { |c| c.to_s.strip }
    contact[:enterprise] = params[:enterprise].present?

    errors = validate(contact)
    return render(json: { error: errors }, status: :unprocessable_entity) if errors.any?

    ContactMailer.with(contact: contact).enquiry.deliver_later
    render json: { ok: true }, status: :created
  end

  private

  def validate(contact)
    required = contact[:enterprise] ? ENTERPRISE_REQUIRED : REQUIRED
    errors = required.filter_map { |k| "#{k.to_s.humanize} is required" if contact[k].blank? }
    errors << "Email is invalid" if contact[:email].present? && !contact[:email].match?(URI::MailTo::EMAIL_REGEXP)
    LIMITS.each { |k, max| errors << "#{k.to_s.humanize} is too long" if contact[k].length > max }
    errors
  end
end
