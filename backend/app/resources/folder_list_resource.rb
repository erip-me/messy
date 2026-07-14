# Flat folder list row with its template summaries.
class FolderListResource < FolderResource
  attribute :templates do |folder|
    folder.templates.map { |t| { id: t.id, name: t.name, trigger: t.trigger } }
  end

  attribute :templates_count do |folder|
    folder.templates.size
  end
end
