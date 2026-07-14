class MobilePushMessage < Message
  validates :to, presence: true
  validates :body, presence: true
end