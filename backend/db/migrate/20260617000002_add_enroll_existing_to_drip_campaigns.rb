class AddEnrollExistingToDripCampaigns < ActiveRecord::Migration[8.0]
  def change
    # true  => on Start, enroll customers already in the segment (+ future entrants)
    # false => only customers who enter the segment after Start are enrolled
    add_column :drip_campaigns, :enroll_existing_on_start, :boolean, null: false, default: true
  end
end
