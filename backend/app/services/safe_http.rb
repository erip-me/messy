require "net/http"
require "resolv"
require "ipaddr"

# Hardened HTTP fetcher for caller-supplied URLs. Resolves the host and rejects
# any address that maps to private/loopback/link-local/reserved space (SSRF
# guard), re-validating on every redirect hop and capping the response size.
module SafeHttp
  class Error < StandardError; end

  DEFAULT_MAX_REDIRECTS = 5
  DEFAULT_MAX_BYTES = 25 * 1024 * 1024
  OPEN_TIMEOUT = 5
  READ_TIMEOUT = 15

  # Reserved ranges not fully covered by IPAddr#private?/#loopback?/#link_local?.
  BLOCKED_RANGES = [
    IPAddr.new("0.0.0.0/8"),      # "this" network
    IPAddr.new("100.64.0.0/10"),  # CGNAT
    IPAddr.new("169.254.0.0/16"), # link-local (incl. 169.254.169.254 metadata)
    IPAddr.new("fc00::/7"),       # unique local
    IPAddr.new("fe80::/10")       # link-local
  ].freeze

  module_function

  # Returns [body, content_type]. Raises SafeHttp::Error on any rejection.
  def fetch(url, max_redirects: DEFAULT_MAX_REDIRECTS, max_bytes: DEFAULT_MAX_BYTES)
    redirects = 0
    uri = parse(url)

    loop do
      guard_host!(uri.host)

      res = request(uri, max_bytes)
      case res
      when Net::HTTPSuccess
        return [res.body, res.content_type.presence || "application/octet-stream"]
      when Net::HTTPRedirection
        raise Error, "too many redirects" if redirects >= max_redirects
        redirects += 1
        uri = parse(URI.join(uri.to_s, res["location"].to_s).to_s)
      else
        raise Error, "#{res.code} for #{uri}"
      end
    end
  rescue SocketError, Timeout::Error => e
    raise Error, e.message
  end

  def parse(url)
    uri = URI.parse(url)
    unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
      raise Error, "unsupported URL '#{url}'"
    end
    raise Error, "missing host in '#{url}'" if uri.host.blank?
    uri
  rescue URI::InvalidURIError
    raise Error, "invalid URL '#{url}'"
  end

  # Rejects if the host resolves to any private/reserved address.
  def guard_host!(host)
    addresses = resolve(host)
    raise Error, "could not resolve host '#{host}'" if addresses.empty?

    addresses.each do |addr|
      ip = IPAddr.new(addr)
      if ip.private? || ip.loopback? || ip.link_local? ||
         BLOCKED_RANGES.any? { |range| range.include?(ip) }
        raise Error, "blocked address for host '#{host}'"
      end
    end
  end

  def resolve(host)
    # A literal IP host resolves to itself; otherwise resolve A and AAAA records.
    return [host] if literal_ip?(host)
    Resolv.getaddresses(host)
  rescue Resolv::ResolvError
    []
  end

  def literal_ip?(host)
    IPAddr.new(host)
    true
  rescue IPAddr::InvalidAddressError
    false
  end

  def request(uri, max_bytes)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.is_a?(URI::HTTPS)
    http.open_timeout = OPEN_TIMEOUT
    http.read_timeout = READ_TIMEOUT

    http.start do |conn|
      req = Net::HTTP::Get.new(uri)
      conn.request(req) do |res|
        if res.is_a?(Net::HTTPSuccess)
          read_capped(res, max_bytes)
        end
        return res
      end
    end
  end

  # Streams the body, aborting if it exceeds max_bytes.
  def read_capped(res, max_bytes)
    body = +""
    res.read_body do |chunk|
      body << chunk
      raise Error, "response exceeds #{max_bytes} bytes" if body.bytesize > max_bytes
    end
    # Net::HTTP normally sets body from read_body; assign so res.body works.
    res.instance_variable_set(:@body, body)
    res.instance_variable_set(:@read, true)
  end
end
