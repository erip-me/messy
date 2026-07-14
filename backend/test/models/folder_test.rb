require "test_helper"

class FolderTest < ActiveSupport::TestCase
  fixtures :all

  test "validates name presence" do
    folder = Folder.new(
      account: accounts(:acme),
      environment: environments(:production),
      name: nil
    )
    assert_not folder.valid?
    assert_includes folder.errors[:name], "can't be blank"
  end

  test "validates name uniqueness per account/environment/parent" do
    existing = folders(:root_folder)
    duplicate = Folder.new(
      account: existing.account,
      environment: existing.environment,
      parent_folder: existing.parent_folder,
      name: existing.name
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end

  test "allows same name in different environments" do
    existing = folders(:root_folder)
    folder = Folder.new(
      account: accounts(:acme),
      environment: environments(:staging),
      name: existing.name
    )
    assert folder.valid?
  end

  test "path returns array of folders from root" do
    sub = folders(:sub_folder)
    root = folders(:root_folder)

    path = sub.path
    assert_equal [root, sub], path
  end

  test "path returns self for root folder" do
    root = folders(:root_folder)
    assert_equal [root], root.path
  end

  test "full_name joins path names" do
    sub = folders(:sub_folder)
    assert_equal "Root Folder / Sub Folder", sub.full_name
  end

  test "full_name for root folder returns just name" do
    root = folders(:root_folder)
    assert_equal "Root Folder", root.full_name
  end

  test "root_folders scope returns only root folders" do
    roots = Folder.root_folders
    assert_includes roots, folders(:root_folder)
    assert_not_includes roots, folders(:sub_folder)
  end

  test "active scope excludes deleted folders" do
    folder = folders(:root_folder)
    folder.update_column(:is_deleted, true)

    active = Folder.active
    assert_not_includes active, folder
    assert_includes active, folders(:sub_folder)
  end
end
