class CampaignEmailMessage
  attr_reader :to, :subject, :html

  def initialize(to:, subject:, html:)
    @to = to
    @subject = subject
    @html = html
  end

  def tagged_subject = subject
  def cc = nil
  def bcc = nil
  def attachments = []
  def inject_tracking_pixel = html
  # Campaign HTML is already link-rewritten + pixel-injected by SendCampaignDeliveryJob.
  def tracked_html = html
end
