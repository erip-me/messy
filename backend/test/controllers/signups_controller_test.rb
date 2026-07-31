require "test_helper"

class SignupsControllerTest < ActionDispatch::IntegrationTest
  SIGNUP_PARAMS = { name: "Jane", email: "jane-signup-test@example.com", account_name: "Acme" }.freeze

  # Rack::Attack counters are process-global and survive between tests, and this
  # file posts /signup more times than the 5/hour throttle allows. Clearing keeps
  # the file order-independent.
  setup { Rack::Attack.cache.store.clear }

  test "signup works without turnstile when no secret configured" do
    post "/signup", params: SIGNUP_PARAMS
    assert_response :created
  end

  # The 409 this used to return was an enumeration oracle: anyone past the
  # captcha could test an address and be told, definitively, whether it had an
  # account here.
  test "signup with an existing email is indistinguishable from a fresh one" do
    post "/signup", params: SIGNUP_PARAMS
    assert_response :created
    fresh_body = response.parsed_body

    assert_no_difference -> { User.count } do
      assert_no_difference -> { Account.count } do
        post "/signup", params: SIGNUP_PARAMS.merge(account_name: "Someone Else")
      end
    end

    assert_response :created
    assert_equal fresh_body, response.parsed_body, "response must not reveal that the email is taken"
  end

  test "the existing owner is notified by email instead" do
    post "/signup", params: SIGNUP_PARAMS
    assert_response :created

    assert_difference -> { SolidQueue::Job.count } => 1 do
      post "/signup", params: SIGNUP_PARAMS
    end
    assert_response :created

    job = SolidQueue::Job.order(:id).last
    assert_equal "ActionMailer::MailDeliveryJob", job.class_name
    assert_includes job.arguments.to_s, "existing_account_notice"
  end

  # A stranger triggers that email, so it must not mint a login token for the
  # owner — that would hand out a live magic link on an attacker's say-so.
  test "the notice points at sign-in rather than minting a magic link" do
    post "/signup", params: SIGNUP_PARAMS
    user = User.find_by(email: SIGNUP_PARAMS[:email])
    token_before = user.magic_link_token

    mail = UserMailer.with(user: user).existing_account_notice
    assert_equal [user.email], mail.to
    assert_equal "You already have a Messy account", mail.subject
    body = mail.html_part&.body.to_s.presence || mail.body.to_s
    assert_includes body, "/login"

    assert_equal token_before, user.reload.magic_link_token

    post "/signup", params: SIGNUP_PARAMS
    assert_equal token_before, user.reload.magic_link_token
  end

  test "signup rejected when turnstile fails" do
    ENV["TURNSTILE_SECRET_KEY"] = "test-secret"
    fake = stub(body: { success: false }.to_json)
    Net::HTTP.stubs(:post_form).returns(fake)

    post "/signup", params: SIGNUP_PARAMS
    assert_response :unprocessable_entity
    assert_match(/Captcha/, response.parsed_body["error"])
  ensure
    ENV.delete("TURNSTILE_SECRET_KEY")
  end

  test "signup accepted when turnstile passes" do
    ENV["TURNSTILE_SECRET_KEY"] = "test-secret"
    fake = stub(body: { success: true }.to_json)
    Net::HTTP.stubs(:post_form).returns(fake)

    post "/signup", params: SIGNUP_PARAMS.merge(turnstile_token: "tok")
    assert_response :created
  ensure
    ENV.delete("TURNSTILE_SECRET_KEY")
  end
end
