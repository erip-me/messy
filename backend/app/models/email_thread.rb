class EmailThread < ApplicationRecord
  belongs_to :account
  belongs_to :mailbox
  belongs_to :conversation

  validates :ticket_number, presence: true, uniqueness: { scope: :account_id }
  validates :from_email, presence: true
  validates :conversation_id, uniqueness: true

  def last_message_detail
    EmailMessageDetail.joins(:conversation_message)
      .where(conversation_messages: { conversation_id: conversation_id })
      .where.not(message_id_header: nil)
      .order(created_at: :desc)
      .first
  end

  def apply_threading_headers!(mail)
    detail = last_message_detail
    return unless detail&.message_id_header

    mail.in_reply_to = detail.message_id_header
    mail.references = "#{references_header} #{detail.message_id_header}".strip
  end

  def requester_and_cc
    ([from_email] + (cc_list || [])).uniq
  end
end
