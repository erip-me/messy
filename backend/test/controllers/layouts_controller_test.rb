require "test_helper"

class LayoutsControllerTest < ActionDispatch::IntegrationTest
  test "index returns layouts" do
    get "/layouts", headers: api_key_headers(environments(:production)), as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_kind_of Array, json
    names = json.map { |l| l["name"] }
    assert_includes names, "Default Email Layout"
  end

  test "show returns layout with transformers" do
    layout = layouts(:default_layout)

    get "/layouts/#{layout.id}", headers: api_key_headers(environments(:production)), as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "Default Email Layout", json["name"]
    assert_kind_of Hash, json["transformers"]
    assert json["transformers"].key?("heading")
  end

  test "create creates layout" do
    assert_difference "Layout.count", 1 do
      post "/layouts",
           params: { name: "New Layout", body: "<html>{{ content }}</html>" },
           headers: api_key_headers(environments(:production)), as: :json
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert_equal "New Layout", json["name"]
  end

  test "create with transformers persists them" do
    transformers = {
      heading: '<h1 style="color:red;">{{text}}</h1>',
      link: '<a href="{{href}}">{{text}}</a>'
    }

    assert_difference "Layout.count", 1 do
      post "/layouts",
           params: { name: "Styled Layout", body: "<html>{{ content }}</html>", transformers: transformers },
           headers: api_key_headers(environments(:production)), as: :json
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert_equal '<h1 style="color:red;">{{text}}</h1>', json["transformers"]["heading"]
    assert_equal '<a href="{{href}}">{{text}}</a>', json["transformers"]["link"]
  end

  test "create without content placeholder returns 422" do
    assert_no_difference "Layout.count" do
      post "/layouts",
           params: { name: "Bad Layout", body: "<html>No placeholder</html>" },
           headers: api_key_headers(environments(:production)), as: :json
    end

    assert_response :unprocessable_entity
  end

  test "update updates layout" do
    layout = layouts(:default_layout)

    put "/layouts/#{layout.id}",
        params: { name: "Updated Layout" },
        headers: api_key_headers(environments(:production)), as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "Updated Layout", json["name"]
  end

  test "update updates transformers" do
    layout = layouts(:default_layout)

    put "/layouts/#{layout.id}",
        params: { transformers: { heading: '<h2>{{text}}</h2>' } },
        headers: api_key_headers(environments(:production)), as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal '<h2>{{text}}</h2>', json["transformers"]["heading"]
  end

  test "destroy deletes layout" do
    layout = layouts(:empty_transformers_layout)

    assert_difference "Layout.count", -1 do
      delete "/layouts/#{layout.id}",
             headers: api_key_headers(environments(:production)), as: :json
    end

    assert_response :no_content
  end
end
