require "test_helper"

class ContactsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  # App-wide adapter is Solid Queue, which the ActiveJob assertions can't inspect.
  def queue_adapter_for_test = ActiveJob::QueueAdapters::TestAdapter.new

  VALID = { name: "Ada Lovelace", email: "ada@example.com", message: "Tell me more." }.freeze

  # The throttle counts every request in this file against the same test IP.
  setup { Rack::Attack.cache.store.clear }

  test "accepts a contact enquiry and emails it, unauthenticated" do
    assert_enqueued_emails 1 do
      post "/contact", params: VALID, as: :json
    end

    assert_response :created
  end

  test "accepts the enterprise questionnaire and includes its answers in the mail" do
    params = VALID.merge(
      enterprise: true, company: "Acme", role: "CTO", company_size: "51-200",
      current_stack: "SendGrid + Twilio", monthly_volume: "100k-1M",
      channels: %w[email sms], interest: "Enterprise licensing",
      timeline: "This quarter", goals: "Consolidate onto one API."
    )

    perform_enqueued_jobs do
      post "/contact", params: params, as: :json
    end

    assert_response :created
    mail = ActionMailer::Base.deliveries.last
    assert_equal "Enterprise enquiry: Acme", mail.subject
    assert_equal ["ada@example.com"], mail.reply_to
    body = mail.html_part&.body.to_s.presence || mail.body.to_s
    assert_includes body, "SendGrid + Twilio"
    assert_includes body, "Consolidate onto one API."
    assert_includes body, "email, sms"
  end

  test "rejects a missing required field" do
    assert_no_enqueued_emails do
      post "/contact", params: VALID.except(:email), as: :json
    end

    assert_response :unprocessable_entity
    assert_includes JSON.parse(response.body)["error"], "Email is required"
  end

  test "rejects a malformed email" do
    assert_no_enqueued_emails do
      post "/contact", params: VALID.merge(email: "not-an-email"), as: :json
    end

    assert_response :unprocessable_entity
    assert_includes JSON.parse(response.body)["error"], "Email is invalid"
  end

  test "rejects an over-long field" do
    assert_no_enqueued_emails do
      post "/contact", params: VALID.merge(message: "x" * 5_001), as: :json
    end

    assert_response :unprocessable_entity
    assert_includes JSON.parse(response.body)["error"], "Message is too long"
  end

  test "enterprise enquiry requires a company" do
    assert_no_enqueued_emails do
      post "/contact", params: VALID.merge(enterprise: true), as: :json
    end

    assert_response :unprocessable_entity
    assert_includes JSON.parse(response.body)["error"], "Company is required"
  end

  test "enterprise enquiry accepts blank goals and message" do
    assert_enqueued_emails 1 do
      post "/contact", params: VALID.except(:message).merge(enterprise: true, company: "Acme"), as: :json
    end

    assert_response :created
  end

  test "honeypot silently swallows the submission" do
    assert_no_enqueued_emails do
      post "/contact", params: VALID.merge(website: "http://spam.example"), as: :json
    end

    # 201 on purpose: a bot must not learn that it was filtered.
    assert_response :created
  end

  test "throttles a flood from one IP" do
    5.times { post "/contact", params: VALID, as: :json }
    assert_response :created

    post "/contact", params: VALID, as: :json
    assert_response :too_many_requests
  end

  # Cloudflare hands each request to a different edge, and the ingress rewrites
  # X-Forwarded-For to that edge. Only CF-Connecting-IP identifies the client, so
  # a flood must share one bucket even as the forwarded-for address changes.
  test "throttles on the Cloudflare client IP, not the rotating edge" do
    flood = lambda do |n|
      post "/contact", params: VALID, as: :json,
           headers: { "CF-Connecting-IP" => "9.9.9.9", "X-Forwarded-For" => "104.23.166.#{n}" }
    end

    5.times { |n| flood.call(n) }
    assert_response :created

    flood.call(99)
    assert_response :too_many_requests
  end

  test "drops unknown fields rather than forwarding them" do
    perform_enqueued_jobs do
      post "/contact", params: VALID.merge(evil: "<script>alert(1)</script>"), as: :json
    end

    body = ActionMailer::Base.deliveries.last.html_part&.body.to_s.presence || ActionMailer::Base.deliveries.last.body.to_s
    assert_not_includes body, "alert(1)"
  end
end
