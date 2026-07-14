require "test_helper"

class FoldersControllerTest < ActionDispatch::IntegrationTest
  test "index returns folders with templates" do
    get "/folders", headers: auth_headers(users(:admin)), as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_kind_of Array, json
    folder = json.find { |f| f["name"] == "Root Folder" }
    assert folder.present?
    assert folder.key?("templates")
  end

  test "create creates folder" do
    assert_difference "Folder.count", 1 do
      post "/folders",
           params: { folder: { name: "New Folder" } },
           headers: auth_headers(users(:admin)), as: :json
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert_equal "New Folder", json["name"]
  end

  test "move moves folder" do
    folder = folders(:sub_folder)
    target = folders(:root_folder)

    post "/folders/#{folder.id}/move",
         params: { target_folder_id: nil },
         headers: auth_headers(users(:admin)), as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_nil json["parent_folder_id"]
  end

  test "destroy soft-deletes folder" do
    folder = folders(:sub_folder)

    delete "/folders/#{folder.id}", headers: auth_headers(users(:admin)), as: :json

    assert_response :no_content
    folder.reload
    assert_equal true, folder.is_deleted
  end
end
