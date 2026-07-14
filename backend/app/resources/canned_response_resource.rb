class CannedResponseResource
  include Alba::Resource

  attributes :id, :shortcut, :title, :content

  attribute :created_by do |r|
    r.created_by&.name
  end
end
