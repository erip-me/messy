class ChatWidgetSettings < ApplicationRecord
  belongs_to :account

  has_one_attached :logo
  has_one_attached :header_background_image
  has_one_attached :chat_background_image

  before_create :generate_widget_key

  validates :account_id, uniqueness: true
  validates :widget_key, uniqueness: true, allow_nil: true
  validates :position, inclusion: { in: %w[bottom-right bottom-left] }
  validates :auto_close_hours, numericality: { greater_than: 0 }, allow_nil: true
  validates :primary_color, format: { with: /\A#[0-9a-fA-F]{6}\z/ }, allow_blank: true
  validates :secondary_color, format: { with: /\A#[0-9a-fA-F]{6}\z/ }, allow_blank: true
  validates :text_color, format: { with: /\A#[0-9a-fA-F]{6}\z/ }, allow_blank: true
  validates :button_color, format: { with: /\A#[0-9a-fA-F]{6}\z/ }, allow_blank: true
  validates :button_text_color, format: { with: /\A#[0-9a-fA-F]{6}\z/ }, allow_blank: true
  validates :header_color, format: { with: /\A#[0-9a-fA-F]{6}\z/ }, allow_blank: true
  validates :header_text_color, format: { with: /\A#[0-9a-fA-F]{6}\z/ }, allow_blank: true
  validates :send_button_color, format: { with: /\A#[0-9a-fA-F]{6}\z/ }, allow_blank: true
  validates :send_button_text_color, format: { with: /\A#[0-9a-fA-F]{6}\z/ }, allow_blank: true

  def within_business_hours?(time = Time.current)
    return true unless business_hours_enabled?

    tz = ActiveSupport::TimeZone[timezone] || ActiveSupport::TimeZone["UTC"]
    local_time = time.in_time_zone(tz)
    day_key = local_time.strftime("%a").downcase
    hours = business_hours[day_key]

    return false if hours.blank?

    start_time = Time.zone.parse("#{local_time.to_date} #{hours['start']}")
    end_time = Time.zone.parse("#{local_time.to_date} #{hours['end']}")
    local_time.between?(start_time, end_time)
  end

  def embed_snippet(base_url)
    <<~HTML
      <script>
        window.MessyConfig = { widgetId: "#{widget_key}" };
      </script>
      <script src="#{base_url}/widget/messy-widget.js" async></script>
    HTML
  end

  def as_widget_json
    {
      enabled: enabled,
      title: title,
      logo_url: logo.attached? ? Rails.application.routes.url_helpers.rails_blob_url(logo) : nil,
      primary_color: primary_color,
      secondary_color: secondary_color,
      text_color: text_color,
      button_color: button_color,
      button_text_color: button_text_color,
      header_color: header_color,
      header_text_color: header_text_color,
      send_button_color: send_button_color,
      send_button_text_color: send_button_text_color,
      header_background_image_url: header_background_image.attached? ? Rails.application.routes.url_helpers.rails_blob_url(header_background_image) : nil,
      chat_background_image_url: chat_background_image.attached? ? Rails.application.routes.url_helpers.rails_blob_url(chat_background_image) : nil,
      position: position,
      greeting_message: greeting_message,
      offline_message: offline_message,
      require_email_before_chat: require_email_before_chat,
      show_operator_avatars: show_operator_avatars,
      show_operator_count: show_operator_count,
      business_hours_enabled: business_hours_enabled,
      business_hours: business_hours,
      timezone: timezone
    }
  end

  private

  def generate_widget_key
    self.widget_key ||= SecureRandom.hex(16)
  end
end
