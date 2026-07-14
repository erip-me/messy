# Folder detail: immediate child folders and the templates it holds.
class FolderWithContentsResource < FolderResource
  attribute :child_folders do |folder|
    folder.child_folders.map { |c| { id: c.id, name: c.name, parent_folder_id: c.parent_folder_id } }
  end

  attribute :templates do |folder|
    folder.templates.map do |t|
      { id: t.id, name: t.name, trigger: t.trigger, created_at: t.created_at, updated_at: t.updated_at }
    end
  end
end
