# Join between a region and a social account (a Meta integration). A region fans
# its ready content out to every channel linked here; an integration can serve
# more than one region.
class CreateSocialChannels < ActiveRecord::Migration[8.0]
  def change
    create_table :social_channels do |t|
      t.references :social_region, null: false, foreign_key: true
      t.references :integration, null: false, foreign_key: true
      t.timestamps
    end

    add_index :social_channels, %i[social_region_id integration_id], unique: true
  end
end
