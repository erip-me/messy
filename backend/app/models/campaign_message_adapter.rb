class CampaignMessageAdapter
  attr_reader :to, :subject, :body, :tags, :account, :environment

  def initialize(campaign:, delivery:, customer:, rendered_content:)
    @to = delivery.email
    @subject = campaign.subject
    @body = rendered_content
    @tags = []
    @account = campaign.account
    @environment = campaign.environment
  end

  def tagged_body = body
  def tagged_subject = subject
  def cc = nil
  def bcc = nil
  def attachments = []
  def inject_tracking_pixel = body
  def language = nil
end
