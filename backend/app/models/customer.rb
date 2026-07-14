class Customer < ApplicationRecord
  belongs_to :account
  has_many :customer_activities, dependent: :destroy
  has_many :device_tokens, dependent: :destroy
  has_many :conversations, dependent: :nullify
  has_many :segment_memberships, dependent: :destroy
  has_many :drip_enrollments, dependent: :destroy

  validates :email, presence: true, unless: :anonymous?
  validates :email, uniqueness: { scope: :account_id, message: 'already exists' },
                    format: { with: URI::MailTo::EMAIL_REGEXP, message: 'is invalid' },
                    allow_blank: true

  def anonymous?
    anonymous_token.present? && email.blank?
  end

  # anonymous_token is the widget visitor's session credential (used to auth
  # widget requests) — never serialize it, even to operators.
  def as_json(options = {})
    super(options).except("anonymous_token")
  end

  # Messages of these categories always send (subject only to the hard
  # per-channel block) — unsubscribing from "marketing" must not stop them.
  TRANSACTIONAL_CATEGORY = "transactional".freeze
  MARKETING_CATEGORY = "marketing".freeze

  # Customers not unsubscribed from the given channel (shared by campaign send
  # and drip projection so the rule lives in one place).
  scope :subscribed_to_channel, ->(channel) { where.not("unsubscribed_channels ? :ch", ch: channel) }
  # Customers not opted out of the given message category (e.g. "marketing").
  scope :subscribed_to_category, ->(category) { where.not("unsubscribed_categories ? :c", c: category) }

  def unsubscribed_from?(channel)
    unsubscribed_channels[channel.to_s].present?
  end

  def unsubscribed_from_category?(category)
    (unsubscribed_categories || {})[category.to_s].present?
  end

  def unsubscribe_from_category!(category, reason: nil)
    value = reason ? { "at" => Time.current.iso8601, "reason" => reason } : Time.current.iso8601
    update!(unsubscribed_categories: (unsubscribed_categories || {}).merge(category.to_s => value))
  end

  def resubscribe_to_category!(category)
    update!(unsubscribed_categories: (unsubscribed_categories || {}).except(category.to_s))
  end

  # Whether a message on `channel` of `category` should be suppressed for this
  # customer. The hard channel block stops everything; a category opt-out only
  # stops non-transactional categories.
  def suppressed_for?(channel:, category: TRANSACTIONAL_CATEGORY)
    return true if unsubscribed_from?(channel)
    category.to_s != TRANSACTIONAL_CATEGORY && unsubscribed_from_category?(category)
  end

  # The address to deliver to for a given channel.
  def address_for(channel)
    case channel.to_s
    when "sms", "whatsapp" then phone
    else email
    end
  end

  # Base Liquid variables for rendering a message to this customer.
  def liquid_variables
    {
      "first_name" => first_name.to_s,
      "last_name" => last_name.to_s,
      "email" => email.to_s,
    }.merge((custom_attributes || {}).transform_values(&:to_s))
  end

  def unsubscribe_from!(channel, reason: nil)
    value = if reason
      { "at" => Time.current.iso8601, "reason" => reason }
    else
      Time.current.iso8601
    end
    channels = unsubscribed_channels.merge(channel.to_s => value)
    update!(unsubscribed_channels: channels)
  end

  def resubscribe_to!(channel)
    channels = unsubscribed_channels.except(channel.to_s)
    update!(unsubscribed_channels: channels)
  end

  def unsubscribe_info(channel)
    value = unsubscribed_channels[channel.to_s]
    return nil unless value

    case value
    when String
      { "at" => value, "reason" => nil }
    when Hash
      value
    else
      { "at" => nil, "reason" => nil }
    end
  end

  # Conditional update so out-of-order async calls never overwrite
  # a newer timestamp with an older one.
  def touch_last_seen(at: Time.current)
    self.class.where(id: id)
      .where("last_seen_at IS NULL OR last_seen_at < ?", at)
      .update_all(last_seen_at: at)
  end

  def touch_last_engaged(at: Time.current)
    self.class.where(id: id)
      .where("last_engaged_at IS NULL OR last_engaged_at < ?", at)
      .update_all(last_engaged_at: at)
  end
end
