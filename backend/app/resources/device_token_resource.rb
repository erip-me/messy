class DeviceTokenResource
  include Alba::Resource

  attributes :id, :platform, :active, :device_id, :app_id, :device_name,
             :last_used_at, :created_at
end
