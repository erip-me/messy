# The posting log: one row per publish attempt to one target — a (post, social
# account, slot, channel) tuple. Modeled on campaign_deliveries so operators can
# see what posted and what failed, with the provider's returned post id and the
# error. account_id is denormalized for tenant-scoped log queries + ActionCable
# broadcasts. No unique constraint: the scheduler enforces idempotency by
# checking for an existing `posted` row, while ad-hoc "post now" may re-post.
class CreateSocialPostDeliveries < ActiveRecord::Migration[8.0]
  def change
    create_table :social_post_deliveries do |t|
      t.references :social_post, null: false, foreign_key: true
      t.references :integration, null: false, foreign_key: true # the target social account
      t.references :account, null: false, foreign_key: true
      t.integer :slot,    null: false            # feed / reel
      t.integer :channel, null: false            # facebook / instagram
      t.integer :status,  null: false, default: 0 # pending / posted / failed / skipped
      t.string   :provider_post_id
      t.text     :error_message
      t.datetime :posted_at
      t.timestamps
    end

    add_index :social_post_deliveries, %i[social_post_id integration_id slot channel],
              name: "idx_social_deliveries_target"
    add_index :social_post_deliveries, %i[account_id status]
  end
end
