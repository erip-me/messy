require 'resolv'
require 'timeout'

class EmailFinder
  PATTERNS = %w[
    {fi}{ln}       {fn}{ln}       {ln}           {fn}.{ln}      {fi}.{ln}
    {fn}           {fi}{mn}{ln}   {fn}{li}       {fn}.{li}      {fi}{li}
    {fi}.{li}      {ln}{fn}       {ln}.{fn}      {ln}{fi}       {ln}.{fi}
    {li}{fn}       {li}.{fn}      {li}{fi}       {li}.{fi}      {fi}{mi}{ln}
    {fi}{mi}.{ln}  {fn}{mi}{ln}   {fn}{mi}       {fn}.{mi}      {fn}.{mi}.{ln}
    {fn}{mn}{ln}   {fn}.{mn}.{ln} {fn}-{ln}      {fi}-{ln}      {fn}-{li}
    {fi}-{li}      {ln}-{fn}      {ln}-{fi}      {li}-{fn}      {li}-{fi}
    {fi}{mi}-{ln}  {fn}-{mi}-{ln} {fn}-{mn}-{ln} {fn}_{ln}      {fi}_{ln}
    {fn}_{li}      {fi}_{li}      {ln}_{fn}      {ln}_{fi}      {li}_{fn}
    {li}_{fi}      {fi}{mi}_{ln}  {fn}_{mi}_{ln} {fn}_{mn}_{ln}
  ].freeze

  SMTP_TIMEOUT = 30
  DNS_TIMEOUT  = 5
  SAFE_EMAIL   = /\A[a-z0-9][a-z0-9._%+\-]*@[a-z0-9.\-]+\.[a-z]{2,}\z/i

  attr_reader :first_name, :middle_name, :last_name, :domain

  def initialize(first_name:, last_name:, domain:, middle_name: nil)
    @first_name  = first_name.to_s.strip.downcase
    @last_name   = last_name.to_s.strip.downcase
    @middle_name = middle_name.to_s.strip.downcase.presence
    @domain      = domain.to_s.strip.downcase
  end

  def generate_emails
    patterns = PATTERNS.dup
    patterns.reject! { |p| p.match?(/\{mi\}|\{mn\}/) } if middle_name.blank?

    patterns.filter_map { |pattern| build_email(pattern) }.uniq
  end

  # Batch-verify emails over a single SMTP connection (all must share one domain).
  # Returns early when stop_on_first_valid is true and a valid email is found.
  def self.batch_verify(emails, stop_on_first_valid: false)
    return [] if emails.blank?

    invalid = emails.find { |e| !e.match?(SAFE_EMAIL) }
    return [{ email: invalid, valid: false, reason: 'invalid_format' }] if invalid

    domain   = emails.first.split('@').last
    mx_hosts = resolve_mx(domain)
    return emails.map { |e| { email: e, valid: false, reason: 'no_mx' } } if mx_hosts.empty?

    batch_smtp_check(emails, mx_hosts.first, stop_on_first_valid: stop_on_first_valid)
  end

  # Streaming variant — yields each result as it completes.
  def self.stream_verify(emails, stop_on_first_valid: false)
    return if emails.blank?

    invalid = emails.find { |e| !e.match?(SAFE_EMAIL) }
    if invalid
      yield({ email: invalid, valid: false, reason: 'invalid_format' })
      return
    end

    domain   = emails.first.split('@').last
    mx_hosts = resolve_mx(domain)
    if mx_hosts.empty?
      emails.each { |e| yield({ email: e, valid: false, reason: 'no_mx' }) }
      return
    end

    mx_host = mx_hosts.first
    checked = Set.new

    begin
      Timeout.timeout(SMTP_TIMEOUT) do
        socket = TCPSocket.new(mx_host, 25)
        begin
          response = socket.gets
          unless response&.start_with?('220')
            emails.each { |e| yield({ email: e, valid: false, reason: 'no_banner', mx: mx_host }) }
            return
          end

          socket.puts "EHLO messy.sh"
          read_multiline(socket)

          socket.puts "MAIL FROM:<verify@messy.sh>"
          resp = socket.gets
          unless resp&.start_with?('250')
            emails.each { |e| yield({ email: e, valid: false, reason: 'mail_from_rejected', mx: mx_host }) }
            return
          end

          emails.each do |email|
            socket.puts "RCPT TO:<#{email}>"
            resp = socket.gets

            valid  = resp&.start_with?('250')
            reason = if valid then 'accepted'
                     elsif resp&.start_with?('550') then 'rejected'
                     else "smtp_#{resp.to_s.strip[0..2]}"
                     end

            checked << email
            yield({ email: email, valid: valid, reason: reason, mx: mx_host })
            break if stop_on_first_valid && valid
          end

          socket.puts "QUIT"
        ensure
          socket.close rescue nil
        end
      end
    rescue Errno::ECONNREFUSED, Errno::ETIMEDOUT, Errno::EHOSTUNREACH, SocketError
      emails.reject { |e| checked.include?(e) }.each do |e|
        yield({ email: e, valid: false, reason: 'connection_failed', mx: mx_host })
      end
    rescue Timeout::Error
      emails.reject { |e| checked.include?(e) }.each do |e|
        yield({ email: e, valid: false, reason: 'timeout', mx: mx_host })
      end
    rescue StandardError
      emails.reject { |e| checked.include?(e) }.each do |e|
        yield({ email: e, valid: false, reason: 'error', mx: mx_host })
      end
    end
  end

  private

  def build_email(pattern)
    result = pattern.dup
    result.gsub!('{fn}', first_name)
    result.gsub!('{fi}', first_name[0].to_s)
    result.gsub!('{mn}', middle_name.to_s)
    result.gsub!('{mi}', middle_name.to_s[0].to_s)
    result.gsub!('{ln}', last_name)
    result.gsub!('{li}', last_name[0].to_s)

    email = "#{result}@#{domain}"
    return nil if email.include?('{}') || result.blank?

    email
  end

  # ── class-level helpers (private) ──────────────────────────────

  def self.resolve_mx(domain)
    resolver = Resolv::DNS.new
    resolver.timeouts = DNS_TIMEOUT
    records = resolver.getresources(domain, Resolv::DNS::Resource::IN::MX)
    records.sort_by(&:preference).map { |r| r.exchange.to_s }
  rescue Resolv::ResolvError, Resolv::ResolvTimeout
    []
  ensure
    resolver&.close
  end
  private_class_method :resolve_mx

  def self.batch_smtp_check(emails, mx_host, stop_on_first_valid:)
    results = []

    Timeout.timeout(SMTP_TIMEOUT) do
      socket = TCPSocket.new(mx_host, 25)
      begin
        response = socket.gets
        unless response&.start_with?('220')
          return emails.map { |e| { email: e, valid: false, reason: 'no_banner', mx: mx_host } }
        end

        socket.puts "EHLO messy.sh"
        read_multiline(socket)

        socket.puts "MAIL FROM:<verify@messy.sh>"
        resp = socket.gets
        unless resp&.start_with?('250')
          return emails.map { |e| { email: e, valid: false, reason: 'mail_from_rejected', mx: mx_host } }
        end

        emails.each do |email|
          socket.puts "RCPT TO:<#{email}>"
          resp = socket.gets

          valid  = resp&.start_with?('250')
          reason = if valid then 'accepted'
                   elsif resp&.start_with?('550') then 'rejected'
                   else "smtp_#{resp.to_s.strip[0..2]}"
                   end

          results << { email: email, valid: valid, reason: reason, mx: mx_host }
          break if stop_on_first_valid && valid
        end

        socket.puts "QUIT"
      ensure
        socket.close rescue nil
      end
    end

    fill_remaining(emails, results, 'not_checked', mx_host)
  rescue Errno::ECONNREFUSED, Errno::ETIMEDOUT, Errno::EHOSTUNREACH, SocketError
    fill_remaining(emails, results, 'connection_failed', mx_host)
  rescue Timeout::Error
    fill_remaining(emails, results, 'timeout', mx_host)
  rescue StandardError
    fill_remaining(emails, results, 'error', mx_host)
  end
  private_class_method :batch_smtp_check

  def self.fill_remaining(emails, results, reason, mx_host)
    checked = results.map { |r| r[:email] }.to_set
    remaining = emails.reject { |e| checked.include?(e) }
    results + remaining.map { |e| { email: e, valid: false, reason: reason, mx: mx_host } }
  end
  private_class_method :fill_remaining

  def self.read_multiline(socket)
    response = ''
    loop do
      line = socket.gets
      break if line.nil?
      response = line
      break unless line[3] == '-'
    end
    response
  end
  private_class_method :read_multiline
end
