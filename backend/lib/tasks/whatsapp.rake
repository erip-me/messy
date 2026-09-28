namespace :whatsapp do
  # Re-proves platform ownership for WhatsApp integrations that have no
  # platform_verified_waba_id (e.g. Embedded Signup connections made before that
  # column existed). Proof comes from Meta, not from config: the stored token must
  # read the WABA's subscribed apps and our META_APP_ID must be among them.
  desc "Mark WhatsApp integrations whose WABA our platform app is subscribed to as platform-verified"
  task reverify: :environment do
    app_id = ENV["META_APP_ID"].presence or abort "META_APP_ID is not set"

    WhatsappIntegration.where(platform_verified_waba_id: nil).find_each do |i|
      next if i.business_account_id.blank? || i.token.blank?
      apps = MetaGraph.get("#{i.business_account_id}/subscribed_apps", token: i.token)["data"] || []
      if apps.any? { |a| a.dig("whatsapp_business_api_data", "id").to_s == app_id }
        i.update_column(:platform_verified_waba_id, i.business_account_id.to_s)
        puts "verified integration #{i.id} (WABA #{i.business_account_id})"
      else
        puts "skipped integration #{i.id}: platform app not subscribed to WABA #{i.business_account_id}"
      end
    rescue MetaGraph::Error => e
      puts "skipped integration #{i.id}: #{e.message}"
    end
  end
end
