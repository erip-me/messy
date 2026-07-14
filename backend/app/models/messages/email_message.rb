class EmailMessage < Message
  validates :to, presence: true
  validates :subject, presence: true
  validates :body, presence: true
end