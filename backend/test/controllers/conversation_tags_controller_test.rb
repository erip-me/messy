require "test_helper"

class ConversationTagsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:admin)
    @headers = auth_headers(@user)
  end

  test "index returns all tags" do
    get "/conversation_tags", headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert json["tags"].length >= 3
  end

  test "create a new tag" do
    assert_difference "ConversationTag.count", 1 do
      post "/conversation_tags",
           params: { name: "Feature request", color: "#8B5CF6", is_quick_reply: false },
           headers: @headers,
           as: :json
    end

    assert_response :created
  end

  test "update a tag" do
    tag = conversation_tags(:bug_tag)
    patch "/conversation_tags/#{tag.id}",
          params: { name: "Bug report updated" },
          headers: @headers,
          as: :json

    assert_response :success
    tag.reload
    assert_equal "Bug report updated", tag.name
  end

  test "destroy a tag" do
    tag = conversation_tags(:bug_tag)
    assert_difference "ConversationTag.count", -1 do
      delete "/conversation_tags/#{tag.id}", headers: @headers
    end

    assert_response :no_content
  end
end
