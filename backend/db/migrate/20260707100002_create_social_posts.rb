# One region's content for one calendar date. Holds the day's alternatives and
# records which alternative's asset fills the feed slot and/or the reel slot
# (mix-and-match across variants). Per-target publish results live in
# social_post_deliveries (added next); the FK constraints for the feed/reel slot
# columns are backfilled in the alternatives migration to avoid a circular
# create-table dependency.
class CreateSocialPosts < ActiveRecord::Migration[8.0]
  def change
    create_table :social_posts do |t|
      t.references :social_region, null: false, foreign_key: true
      t.date    :post_date, null: false
      t.integer :status, null: false, default: 0 # pending / ready / posted / failed / skipped

      # Which alternative's asset goes out in each slot (nullable; either or both).
      t.bigint :feed_alternative_id
      t.bigint :reel_alternative_id

      t.text :publish_error
      t.timestamps
    end

    add_index :social_posts, %i[social_region_id post_date], unique: true
    add_index :social_posts, :feed_alternative_id
    add_index :social_posts, :reel_alternative_id
  end
end
