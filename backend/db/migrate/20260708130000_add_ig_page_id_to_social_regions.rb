class AddIgPageIdToSocialRegions < ActiveRecord::Migration[8.0]
  # The Facebook Page whose token publishes to the selected Instagram account.
  # IG accounts can belong to a different Page than the one chosen for Facebook,
  # so the token used for IG publishing is minted from this Page, not page_id.
  def change
    add_column :social_regions, :ig_page_id, :string
  end
end
