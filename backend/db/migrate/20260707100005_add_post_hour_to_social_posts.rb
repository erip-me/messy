# Per-post override of the publish hour. When null, the day posts at its region's
# default post_hour; when set (0-23, region-local), it overrides just this day.
class AddPostHourToSocialPosts < ActiveRecord::Migration[8.0]
  def change
    add_column :social_posts, :post_hour, :integer
  end
end
