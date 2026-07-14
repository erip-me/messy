require "test_helper"

class RulesControllerTest < ActionDispatch::IntegrationTest
  test "index returns rules with serialized format" do
    get "/rules", headers: auth_headers(users(:admin)), as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_kind_of Array, json

    rule = json.find { |r| r["name"] == "Allow Internal Emails" }
    assert rule.present?
    assert_equal "deliver", rule["outcome"]
    assert rule.key?("type")
    assert rule.key?("condition")
  end

  test "create creates rule with raw JSON body" do
    headers = auth_headers(users(:admin)).merge("CONTENT_TYPE" => "application/json")

    assert_difference "Rule.count", 1 do
      post "/rules",
           params: { type: "email", name: "New Rule", condition: "domain == 'test.com'", outcome: "block" }.to_json,
           headers: headers
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert_equal "New Rule", json["name"]
    assert_equal "block", json["outcome"]
  end

  test "update updates rule" do
    rule = rules(:allow_internal)

    patch "/rules/#{rule.id}",
          params: { rule: { name: "Updated Rule Name" } },
          headers: auth_headers(users(:admin)), as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "Updated Rule Name", json["name"]
  end

  test "destroy destroys rule" do
    rule = rules(:block_external)

    assert_difference "Rule.count", -1 do
      delete "/rules/#{rule.id}", headers: auth_headers(users(:admin)), as: :json
    end

    assert_response :no_content
  end
end
