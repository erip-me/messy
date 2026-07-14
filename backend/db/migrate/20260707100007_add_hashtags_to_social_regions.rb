# A per-region pool of hashtags. When a day's caption is built, the 3-5 that best
# match the creative's copy are appended for tag searchability.
class AddHashtagsToSocialRegions < ActiveRecord::Migration[8.0]
  def change
    add_column :social_regions, :hashtags, :jsonb, null: false, default: []
  end
end
