class Template < ApplicationRecord
  belongs_to :account
  belongs_to :environment
  belongs_to :folder, optional: true
  belongs_to :layout, optional: true
  # Default "send as" identity for messages built from this template.
  belongs_to :sending_identity, optional: true

  has_many_attached :attachments

  validate :sending_identity_belongs_to_account, if: :sending_identity_id

  # validate message also be send custom message like if trigger error then send trigger is also present
  CHANNELS = %w[email sms whatsapp push].freeze
  BODY_FORMATS = %w[html markdown].freeze

  validates :trigger, presence: true, uniqueness: { scope: [:environment_id, :channel], conditions: -> { where(is_deleted: false) } }
  validates :name, presence: true
  validates :body, presence: true
  validates :channel, presence: true, inclusion: { in: CHANNELS }
  validates :body_format, presence: true, inclusion: { in: BODY_FORMATS }

  # Attachment summary shared by the template API and the render endpoint.
  def attachments_summary
    attachments.map { |a| { id: a.id, filename: a.filename.to_s, content_type: a.content_type, byte_size: a.byte_size } }
  end

  private

  def sending_identity_belongs_to_account
    errors.add(:sending_identity, "must belong to the same account") if sending_identity && sending_identity.account_id != account_id
  end
end
