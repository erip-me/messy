require "test_helper"

class SendingIdentitiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:admin)
    @account = accounts(:acme)
    @headers = auth_headers(@user)
  end

  test "creates an identity" do
    assert_difference -> { SendingIdentity.count }, 1 do
      post sending_identities_path, params: { from_name: "Peter", from_email: "peter@lalaaji.com" }, headers: @headers
    end
    assert_response :created
    assert_equal "peter@lalaaji.com", JSON.parse(response.body)["from_email"]
  end

  test "rejects an invalid email" do
    post sending_identities_path, params: { from_email: "nope" }, headers: @headers
    assert_response :unprocessable_entity
  end

  test "only one default per account — setting a new default demotes the old" do
    a = @account.sending_identities.create!(from_email: "a@lalaaji.com", is_default: true)
    post sending_identities_path, params: { from_email: "b@lalaaji.com", is_default: "true" }, headers: @headers
    assert_response :created

    assert_not a.reload.is_default
    assert_equal 1, @account.sending_identities.where(is_default: true).count
  end

  test "index is scoped to the account" do
    @account.sending_identities.create!(from_email: "mine@lalaaji.com")
    accounts(:other_co).sending_identities.create!(from_email: "theirs@other.com")

    get sending_identities_path, headers: @headers
    emails = JSON.parse(response.body).map { |i| i["from_email"] }
    assert_includes emails, "mine@lalaaji.com"
    assert_not_includes emails, "theirs@other.com"
  end

  test "deletes an identity" do
    id = @account.sending_identities.create!(from_email: "x@lalaaji.com")
    assert_difference -> { SendingIdentity.count }, -1 do
      delete sending_identity_path(id), headers: @headers
    end
    assert_response :success
  end

  test "index accepts an environment API key, scoped to its account" do
    @account.sending_identities.create!(from_email: "mine@lalaaji.com")
    accounts(:other_co).sending_identities.create!(from_email: "theirs@other.com")

    get sending_identities_path, headers: api_key_headers(environments(:production))

    assert_response :success
    emails = JSON.parse(response.body).map { |i| i["from_email"] }
    assert_includes emails, "mine@lalaaji.com"
    assert_not_includes emails, "theirs@other.com"
  end

  test "index filters by personal and exposes the flag" do
    @account.sending_identities.create!(from_email: "peter@lalaaji.com", personal: true)
    @account.sending_identities.create!(from_email: "noreply@lalaaji.com")

    get sending_identities_path, params: { personal: "true" }, headers: api_key_headers(environments(:production))

    json = JSON.parse(response.body)
    assert_equal ["peter@lalaaji.com"], json.map { |i| i["from_email"] }
    assert_equal true, json.first["personal"]
  end

  test "index rejects a missing or bogus key" do
    get sending_identities_path, headers: { "Authorization" => "Bearer nope" }
    assert_response :unauthorized
  end

  test "an API key cannot create identities" do
    assert_no_difference -> { SendingIdentity.count } do
      post sending_identities_path, params: { from_email: "x@lalaaji.com" }, headers: api_key_headers(environments(:production))
    end
    assert_response :unauthorized
  end

  test "personal can be toggled" do
    id = @account.sending_identities.create!(from_email: "p@lalaaji.com")
    put sending_identity_path(id), params: { personal: "true" }, headers: @headers
    assert_response :success
    assert id.reload.personal
  end
end
