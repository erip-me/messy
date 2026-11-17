# Configure AWS SDK
# In ECS, credentials are automatically provided via the task role
# Only set explicit credentials if AWS_ACCESS_KEY_ID is present (for local development)
if ENV['AWS_ACCESS_KEY_ID'].present? && ENV['AWS_SECRET_ACCESS_KEY'].present?
  Aws.config.update(
    region: ENV['AWS_REGION'],
    credentials: Aws::Credentials.new(ENV['AWS_ACCESS_KEY_ID'], ENV['AWS_SECRET_ACCESS_KEY'])
  )
else
  # Use default credential provider chain (includes ECS task role)
  Aws.config.update(
    region: ENV['AWS_REGION']
  )
end

# Configure SES to use eu-west-1 (verified identities are in this region)
Aws::Rails.add_action_mailer_delivery_method(
  :ses,
  region: 'eu-west-1'
)

# The Active Storage bucket (storage.yml `s3`) has its own key. A global
# `credentials:` above beats the access_key_id/secret in storage.yml, so the
# bucket would be signed with the SES key; S3-scoped config beats global.
if ENV['STORAGE_S3_ACCESS_KEY_ID'].present? && ENV['STORAGE_S3_SECRET_ACCESS_KEY'].present?
  Aws.config[:s3] = {
    credentials: Aws::Credentials.new(ENV['STORAGE_S3_ACCESS_KEY_ID'], ENV['STORAGE_S3_SECRET_ACCESS_KEY'])
  }
end
