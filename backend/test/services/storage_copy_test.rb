require "test_helper"

class StorageCopyTest < ActiveSupport::TestCase
  test "copies files to the new service and repoints the blobs" do
    dir = Dir.mktmpdir
    original = ActiveStorage::Blob.services
    configs = Rails.configuration.active_storage.service_configurations.merge(
      "copy_target" => { "service" => "Disk", "root" => dir }
    )
    ActiveStorage::Blob.services = ActiveStorage::Service::Registry.new(configs)
    target = ActiveStorage::Blob.services.fetch(:copy_target)

    blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("logo"), filename: "l.png")
    result = StorageCopy.call(from: "test", to: "copy_target", log: StringIO.new)

    assert_equal 1, result[:copied]
    assert_equal "copy_target", blob.reload.service_name
    assert_equal "logo", target.download(blob.key)
    assert_equal 0, StorageCopy.call(from: "test", to: "copy_target", log: StringIO.new)[:copied]
  ensure
    ActiveStorage::Blob.services = original if original
    FileUtils.rm_rf(dir) if dir
  end
end
