class EmailVerifier
  SMTP_TIMEOUT = 10
  DNS_TIMEOUT  = 5

  DISPOSABLE_DOMAINS = %w[
    mailinator.com guerrillamail.com tempmail.com throwaway.email
    yopmail.com sharklasers.com guerrillamailblock.com grr.la
    dispostable.com trashmail.com temp-mail.org fakeinbox.com
    maildrop.cc mailnesia.com mintemail.com mohmal.com
    getnada.com emailondeck.com 10minutemail.com guerrillamail.info
    guerrillamail.net guerrillamail.org guerrillamail.de spam4.me
    trashmail.me trashmail.net harakirimail.com mailexpire.com
    tempail.com tempr.email throwam.com trash-mail.com
    binkmail.com filzmail.com lookugly.com mailcatch.com
    mailmoat.com mytrashmail.com spamfree24.org spaml.com
    uglymail.com mailnull.com jetable.org incognitomail.org
    discardmail.com disposeamail.com mailzilla.com anonmails.de
    burnermail.io guerrillamail.biz cuvox.de armyspy.com
    dayrep.com einrot.com fleckens.hu jourrapide.com
    rhyta.com superrito.com teleworm.us
  ].to_set.freeze

  ROLE_PREFIXES = %w[
    info noreply no-reply admin support sales marketing
    webmaster postmaster hostmaster abuse contact help
    office team feedback billing
  ].to_set.freeze

  Result = Struct.new(:score, :checks, keyword_init: true)

  def initialize(email)
    @email = email.to_s.strip.downcase
    @local, @domain = @email.split('@', 2)
    @checks = {}
  end

  def verify
    unless valid_syntax?
      @checks[:syntax] = :invalid
      return Result.new(score: 0, checks: @checks)
    end
    @checks[:syntax] = :valid

    @checks[:disposable] = disposable_domain?
    @checks[:role_based] = role_based_email?

    mx_hosts = lookup_mx_records
    if mx_hosts.nil?
      @checks[:mx] = :dns_error
      return Result.new(score: 30, checks: @checks)
    elsif mx_hosts.empty?
      @checks[:mx] = :no_records
      return Result.new(score: 0, checks: @checks)
    end
    @checks[:mx] = :found

    smtp_code = verify_smtp(mx_hosts.first)
    @checks[:smtp] = smtp_code

    score = compute_score(smtp_code)
    Result.new(score: score, checks: @checks)
  end

  private

  def valid_syntax?
    @email.match?(URI::MailTo::EMAIL_REGEXP) && @domain.present? && @local.present?
  end

  def disposable_domain?
    DISPOSABLE_DOMAINS.include?(@domain)
  end

  def role_based_email?
    ROLE_PREFIXES.include?(@local)
  end

  def lookup_mx_records
    resolver = Resolv::DNS.new
    resolver.timeouts = DNS_TIMEOUT
    records = resolver.getresources(@domain, Resolv::DNS::Resource::IN::MX)
    records.sort_by(&:preference).map { |r| r.exchange.to_s }
  rescue Resolv::ResolvError, Resolv::ResolvTimeout
    nil
  ensure
    resolver&.close
  end

  def verify_smtp(mx_host)
    Timeout.timeout(SMTP_TIMEOUT) do
      socket = TCPSocket.new(mx_host, 25)
      response = socket.gets
      return :connect_rejected unless response&.start_with?('220')

      socket.puts "EHLO messy.sh"
      response = read_multiline(socket)
      return :ehlo_rejected unless response&.start_with?('250')

      socket.puts "MAIL FROM:<verify@messy.sh>"
      response = socket.gets
      return :mail_from_rejected unless response&.start_with?('250')

      socket.puts "RCPT TO:<#{@email}>"
      response = socket.gets

      socket.puts "QUIT"
      socket.close

      return :accepted if response&.start_with?('250')
      return :rejected if response&.match?(/^5[0-5]\d/)
      :unknown
    end
  rescue Timeout::Error
    :timeout
  rescue Errno::ECONNREFUSED
    :connection_refused
  rescue Errno::EHOSTUNREACH, Errno::ENETUNREACH
    :host_unreachable
  rescue StandardError
    :error
  end

  def read_multiline(socket)
    response = ""
    loop do
      line = socket.gets
      break if line.nil?
      response = line
      break unless line[3] == '-'
    end
    response
  end

  def compute_score(smtp_code)
    base_score = case smtp_code
                 when :accepted           then 100
                 when :rejected           then 0
                 when :connect_rejected   then 40
                 when :timeout            then 40
                 when :connection_refused then 40
                 when :host_unreachable   then 20
                 when :ehlo_rejected      then 40
                 when :mail_from_rejected then 40
                 when :unknown            then 50
                 when :error              then 40
                 else 40
                 end

    return base_score if base_score == 0

    base_score -= 60 if @checks[:disposable]
    base_score -= 10 if @checks[:role_based]

    base_score.clamp(0, 100)
  end
end
