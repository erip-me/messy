class WebPushMessage < Message
  validates :to, presence: true
  validates :body, presence: true
end