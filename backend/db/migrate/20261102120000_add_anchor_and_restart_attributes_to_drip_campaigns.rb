class AddAnchorAndRestartAttributesToDripCampaigns < ActiveRecord::Migration[8.0]
  def change
    # Schedule steps relative to a date custom attribute instead of the previous send.
    add_column :drip_campaigns, :anchor_attribute, :string
    # Restart the enrollment when this custom attribute changes value.
    add_column :drip_campaigns, :restart_attribute, :string
  end
end
