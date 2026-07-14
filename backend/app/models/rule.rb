class Rule < ApplicationRecord
  belongs_to :account
  belongs_to :environment

  enum :scope, {
    any: 0,
    internal: 1,
    external: 2
  }

  enum :outcome, {
    deny: 0,
    allow: 1,
    redirect: 2
  }

  TYPE_MAP = {
    'email'    => 'EmailRule',
    'sms'      => 'SmsRule',
    'whatsapp' => 'WhatsappRule',
    'push'     => 'MobilePushRule',
    'web_push' => 'WebPushRule',
  }.freeze

  OUTCOME_MAP = {
    'block'    => 'deny',
    'deliver'  => 'allow',
    'redirect' => 'redirect',
  }.freeze

  def channel_type
    self.class.name.sub('Rule', '').downcase
  end

  def passes?(message, rcpt)
    if rcpt.downcase.include?(condition.downcase)
      return outcome == 'allow' ? :allow : :deny
    end

    return :continue
  end
end
