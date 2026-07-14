require "test_helper"

# Verifies the seller segmentation model built on custom_attributes:
#   - is_seller        (true/false)
#   - signup_campaign  (nil / "" / "meta")
#   - is_draft         (true/false) -- third dimension for unactivated meta sellers
#
# Segments are query-based: a customer is "in" a segment whenever they currently
# match its conditions, and exits the moment their attributes stop matching.
class SellerSegmentsTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:acme)

    # A meta seller who has activated their account.
    @meta_active = create_customer("meta-active@sellers.test",
      is_seller: true, signup_campaign: "meta", is_draft: false)

    # A meta seller who has NOT activated yet (draft).
    @meta_draft = create_customer("meta-draft@sellers.test",
      is_seller: true, signup_campaign: "meta", is_draft: true)

    # A direct (website) seller -- signup_campaign key absent entirely.
    @direct_seller = create_customer("direct@sellers.test",
      is_seller: true)

    # A direct seller whose signup_campaign was written as an empty string.
    @direct_seller_blank = create_customer("direct-blank@sellers.test",
      is_seller: true, signup_campaign: "")

    # A non-seller who happens to carry the meta campaign tag -- must never match.
    @non_seller_meta = create_customer("buyer-meta@sellers.test",
      is_seller: false, signup_campaign: "meta")

    # A plain customer with no seller attributes at all.
    @plain = create_customer("plain@sellers.test")
  end

  test "meta seller segment matches only sellers tagged with the meta campaign" do
    ids = evaluate(meta_seller_conditions).pluck(:id)

    assert_includes ids, @meta_active.id
    assert_includes ids, @meta_draft.id, "draft meta sellers are still meta sellers"
    assert_not_includes ids, @direct_seller.id
    assert_not_includes ids, @direct_seller_blank.id
    assert_not_includes ids, @non_seller_meta.id, "non-sellers must be excluded even with a meta tag"
    assert_not_includes ids, @plain.id
  end

  test "direct seller segment matches sellers with no signup_campaign (missing or empty)" do
    ids = evaluate(direct_seller_conditions).pluck(:id)

    assert_includes ids, @direct_seller.id, "absent signup_campaign key counts as blank"
    assert_includes ids, @direct_seller_blank.id, "empty-string signup_campaign counts as blank"
    assert_not_includes ids, @meta_active.id
    assert_not_includes ids, @meta_draft.id
    assert_not_includes ids, @non_seller_meta.id
    assert_not_includes ids, @plain.id
  end

  test "draft segment isolates unactivated meta sellers only" do
    ids = evaluate(draft_meta_seller_conditions).pluck(:id)

    assert_includes ids, @meta_draft.id
    assert_not_includes ids, @meta_active.id, "activated meta sellers are not drafts"
    assert_not_includes ids, @direct_seller.id
    assert_not_includes ids, @non_seller_meta.id
    assert_not_includes ids, @plain.id
  end

  test "meta and direct seller segments are mutually exclusive" do
    meta_ids   = evaluate(meta_seller_conditions).pluck(:id).to_set
    direct_ids = evaluate(direct_seller_conditions).pluck(:id).to_set

    assert_empty (meta_ids & direct_ids),
      "a seller cannot be both a meta seller and a direct seller at once"
  end

  test "draft segment is a strict subset of the meta seller segment" do
    meta_ids  = evaluate(meta_seller_conditions).pluck(:id).to_set
    draft_ids = evaluate(draft_meta_seller_conditions).pluck(:id).to_set

    assert draft_ids.subset?(meta_ids),
      "every draft seller must also appear in the meta seller segment"
    assert draft_ids.size < meta_ids.size,
      "draft is a narrower dimension than the full meta seller set"
  end

  test "activating a draft seller moves them out of the draft segment" do
    assert_includes evaluate(draft_meta_seller_conditions).pluck(:id), @meta_draft.id

    @meta_draft.update!(custom_attributes: @meta_draft.custom_attributes.merge("is_draft" => false))

    refute_includes evaluate(draft_meta_seller_conditions).pluck(:id), @meta_draft.id,
      "once activated, the seller exits the draft segment"
    assert_includes evaluate(meta_seller_conditions).pluck(:id), @meta_draft.id,
      "but remains a meta seller"
  end

  test "the segments stay within the account base scope" do
    other_seller = Customer.create!(
      account: accounts(:other_co),
      email: "meta-active@sellers.test",
      custom_attributes: { "is_seller" => true, "signup_campaign" => "meta" }
    )

    ids = evaluate(meta_seller_conditions).pluck(:id)

    assert_not_includes ids, other_seller.id, "another account's seller must never leak in"
  end

  private

  def create_customer(email, attrs = {})
    Customer.create!(
      account: @account,
      email: email,
      custom_attributes: attrs.transform_keys(&:to_s)
    )
  end

  def evaluate(conditions)
    SegmentEvaluator.new(@account.customers, conditions).evaluate
  end

  def meta_seller_conditions
    {
      "operator" => "and",
      "conditions" => [
        { "attribute" => "custom.is_seller", "operator" => "equals", "value" => "true" },
        { "attribute" => "custom.signup_campaign", "operator" => "equals", "value" => "meta" }
      ]
    }
  end

  def direct_seller_conditions
    {
      "operator" => "and",
      "conditions" => [
        { "attribute" => "custom.is_seller", "operator" => "equals", "value" => "true" },
        { "attribute" => "custom.signup_campaign", "operator" => "is_blank" }
      ]
    }
  end

  def draft_meta_seller_conditions
    {
      "operator" => "and",
      "conditions" => [
        { "attribute" => "custom.is_seller", "operator" => "equals", "value" => "true" },
        { "attribute" => "custom.signup_campaign", "operator" => "equals", "value" => "meta" },
        { "attribute" => "custom.is_draft", "operator" => "equals", "value" => "true" }
      ]
    }
  end
end
