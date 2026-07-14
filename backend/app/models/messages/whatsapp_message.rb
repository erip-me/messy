class WhatsappMessage < Message
  validates :to, presence: true
  validates :body, presence: true, unless: :template_message?

  # For template messages, subject holds the template name
  # and body can be auto-set for record-keeping
  before_validation :set_template_body, if: :template_message?

  private

  def template_message?
    subject.present?
  end

  def set_template_body
    self.body = "[WhatsApp Template: #{subject}]" if body.blank?
  end
end
