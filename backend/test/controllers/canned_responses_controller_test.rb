require "test_helper"

class CannedResponsesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:admin)
    @headers = auth_headers(@user)
  end

  test "index returns all canned responses" do
    get "/canned_responses", headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert json["canned_responses"].length >= 2
  end

  test "index with search" do
    get "/canned_responses", params: { q: "greeting" }, headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert json["canned_responses"].any? { |r| r["shortcut"] == "/greeting" }
  end

  test "create a canned response" do
    assert_difference "CannedResponse.count", 1 do
      post "/canned_responses",
           params: { shortcut: "/thanks", title: "Thanks", content: "Thank you for contacting us!" },
           headers: @headers,
           as: :json
    end

    assert_response :created
  end

  test "update a canned response" do
    cr = canned_responses(:greeting)
    patch "/canned_responses/#{cr.id}",
          params: { content: "Updated greeting" },
          headers: @headers,
          as: :json

    assert_response :success
    cr.reload
    assert_equal "Updated greeting", cr.content
  end

  test "destroy a canned response" do
    cr = canned_responses(:pricing)
    assert_difference "CannedResponse.count", -1 do
      delete "/canned_responses/#{cr.id}", headers: @headers
    end

    assert_response :no_content
  end

  test "enforces shortcut uniqueness" do
    post "/canned_responses",
         params: { shortcut: "/greeting", title: "Dup", content: "Dup" },
         headers: @headers,
         as: :json

    # Uniqueness violation is a validation error -> clean 422, not a leaked 500.
    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert(Array(json["error"]).any? { |m| m.include?("Shortcut") })
  end
end
