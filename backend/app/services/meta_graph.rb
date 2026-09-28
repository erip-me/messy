require "net/http"
require "resolv"

# Minimal Meta Graph API client for the WhatsApp Cloud API. Errors carry Meta's
# message and code but never the request URL or token (the code exchange puts the
# app secret in the query string).
module MetaGraph
  class Error < StandardError
    attr_reader :status, :code

    def initialize(message, status: nil, code: nil)
      super(message)
      @status = status
      @code = code
    end
  end

  VERSION = ENV.fetch("META_GRAPH_API_VERSION", "v26.0").freeze
  HOST = "graph.facebook.com".freeze

  module_function

  def get(path, token: nil, **query)
    request(Net::HTTP::Get, path, token: token, query: query)
  end

  def post(path, token:, body: {})
    request(Net::HTTP::Post, path, token: token, body: body)
  end

  def request(klass, path, token:, query: {}, body: nil)
    uri = URI("https://#{HOST}/#{VERSION}/#{path}")
    uri.query = URI.encode_www_form(query) if query.present?
    req = klass.new(uri)
    req["Authorization"] = "Bearer #{token}" if token
    if body
      req["Content-Type"] = "application/json"
      req.body = body.to_json
    end

    res = http(uri).request(req)
    data = JSON.parse(res.body.presence || "{}") rescue {}
    return data if res.is_a?(Net::HTTPSuccess)

    err = data.is_a?(Hash) ? (data["error"] || {}) : {}
    raise Error.new("Graph API #{res.code}: #{err["message"] || "unexpected response"}",
                    status: res.code.to_i, code: err["code"])
  rescue SocketError, Timeout::Error, Errno::ECONNREFUSED, OpenSSL::SSL::SSLError => e
    raise Error, "Graph API unreachable: #{e.class}"
  end

  # Downloads a media URL returned by GET /{media-id}; Meta requires the same
  # bearer token. Returns the body, aborting past max_bytes.
  def download(url, token:, max_bytes:)
    uri = URI(url)
    raise Error, "unexpected media host" unless uri.is_a?(URI::HTTPS)

    req = Net::HTTP::Get.new(uri)
    req["Authorization"] = "Bearer #{token}"
    body = +""
    http(uri).request(req) do |res|
      raise Error.new("media download #{res.code}", status: res.code.to_i) unless res.is_a?(Net::HTTPSuccess)
      res.read_body do |chunk|
        body << chunk
        raise Error, "media exceeds #{max_bytes} bytes" if body.bytesize > max_bytes
      end
    end
    body
  end

  # Pinned to an IPv4 address, as the original WhatsApp sender did in production.
  def http(uri)
    h = Net::HTTP.new(uri.host, uri.port)
    h.use_ssl = true
    h.open_timeout = 5
    h.read_timeout = 30
    h.ipaddr = Resolv::DNS.new.getresource(uri.host, Resolv::DNS::Resource::IN::A).address.to_s
    h
  rescue Resolv::ResolvError
    raise Error, "Graph API unreachable: DNS"
  end
end
