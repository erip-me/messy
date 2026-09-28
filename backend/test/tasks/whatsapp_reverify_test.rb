require "test_helper"
require "rake"

class WhatsappReverifyTaskTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks if Rake::Task.tasks.none? { |t| t.name == "whatsapp:reverify" }
    Rake::Task["whatsapp:reverify"].reenable
    @integration = integrations(:whatsapp)
  end

  test "verifies only integrations whose WABA Meta says our app is subscribed to" do
    MetaGraph.expects(:get).with("9876543210/subscribed_apps", token: "test_whatsapp_token")
      .returns("data" => [{ "whatsapp_business_api_data" => { "id" => "app123" } }])

    with_env("META_APP_ID" => "app123") { capture_io { Rake::Task["whatsapp:reverify"].invoke } }

    assert @integration.reload.platform_verified?
  end

  test "leaves integrations unverified when our app isn't subscribed" do
    MetaGraph.expects(:get).returns("data" => [{ "whatsapp_business_api_data" => { "id" => "someone-else" } }])

    with_env("META_APP_ID" => "app123") { capture_io { Rake::Task["whatsapp:reverify"].invoke } }

    refute @integration.reload.platform_verified?
  end

  private

  def with_env(vars)
    old = vars.keys.to_h { |k| [k, ENV[k]] }
    vars.each { |k, v| ENV[k] = v }
    yield
  ensure
    old.each { |k, v| ENV[k] = v }
  end
end
