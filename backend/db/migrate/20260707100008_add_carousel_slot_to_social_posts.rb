# Carousel is a third slot alongside feed and reel: a day can pick one creative's
# ordered carousel images to publish as a native FB/IG carousel. The images
# themselves are a has_many_attached on the alternative (Active Storage), so only
# the picked-creative pointer needs a column here.
class AddCarouselSlotToSocialPosts < ActiveRecord::Migration[8.0]
  def change
    add_column :social_posts, :carousel_alternative_id, :bigint
    add_index :social_posts, :carousel_alternative_id
    add_foreign_key :social_posts, :social_alternatives, column: :carousel_alternative_id, on_delete: :nullify
  end
end
