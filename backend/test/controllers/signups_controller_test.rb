require "test_helper"

class SignupsControllerTest < ActionDispatch::IntegrationTest
  SIGNUP_PARAMS = { name: "Jane", email: "jane-signup-test@example.com", account_name: "Acme" }.freeze

  test "signup works without turnstile when no secret configured" do
    post "/signup", params: SIGNUP_PARAMS
    assert_response :created
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
