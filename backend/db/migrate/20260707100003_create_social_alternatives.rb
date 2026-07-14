# A creative variant within a day: editable copy plus a 4:5 feed render and a
# 9:16 reel render (Active Storage attachments — image or video). Any variant can
# be drafted into Meta Ads Manager as a PAUSED lead-gen ad; the returned Meta ids
# live here. Also backfills the deferred FK constraints for the post's feed/reel
# slots (ON DELETE SET NULL so deleting a picked variant just clears the slot).
class CreateSocialAlternatives < ActiveRecord::Migration[8.0]
  def change
    create_table :social_alternatives do |t|
      t.references :social_post, null: false, foreign_key: true
      t.string  :headline
      t.text    :body
      t.string  :cta_label
      t.string  :cta_url
      t.integer :position, null: false, default: 0
      t.integer :source, null: false, default: 0 # generated / manual

      # Meta Marketing API linkage (set when the variant is drafted as an ad).
      t.string  :meta_campaign_id
      t.string  :meta_adset_id
      t.string  :meta_ad_id
      t.string  :meta_creative_id
      t.string  :meta_form_id
      t.string  :meta_image_hash
      t.decimal :meta_budget, precision: 10, scale: 2
      t.datetime :drafted_at

      t.timestamps
    end

    add_index :social_alternatives, :meta_ad_id

    add_foreign_key :social_posts, :social_alternatives, column: :feed_alternative_id, on_delete: :nullify
    add_foreign_key :social_posts, :social_alternatives, column: :reel_alternative_id, on_delete: :nullify
  end
end
