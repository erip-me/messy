class SendingIdentity < ApplicationRecord
  belongs_to :account

  validates :from_email, presence: true,
            format: { with: URI::MailTo::EMAIL_REGEXP, message: "is not a valid email address" }

  # "Name <email>" if a display name is set, otherwise the bare address.
  def formatted_from
    from_name.present? ? "#{from_name} <#{from_email}>" : from_email
  end

  # The from line to use for a send: the explicitly chosen identity, else the
  # account's default identity, else nil (delivery falls back to the
  # integration's configured from).
  def self.from_line(identity, account)
    (identity || account&.default_sending_identity)&.formatted_from
  end
end
