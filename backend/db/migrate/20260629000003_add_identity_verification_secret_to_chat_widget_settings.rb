class AddIdentityVerificationSecretToChatWidgetSettings < ActiveRecord::Migration[8.0]
  def change
    # When set, widget identify calls must include a valid HMAC of the email
    # (signed by the embedding site) before a customer identity is linked or
    # overwritten — preventing identity takeover from the public widget surface.
    add_column :chat_widget_settings, :identity_verification_secret, :string
  end
end
