require "json"

# A LinkedIn credential connected via OAuth: an access token (+ refresh token)
# that can publish to the Organization pages the connecting member administers.
# The publishing target (which organization) lives on the region, not here — one
# credential can serve many regions/markets.
#
# Tokens are obtained through SocialOauth::Linkedin (authorize → callback), never
# pasted by hand. Posting uses the versioned REST Posts API; images are uploaded
# via the Images API (initialize → PUT bytes → reference the returned URN),
# because LinkedIn ingests the binary rather than fetching a URL like Meta does.
class LinkedinSocialIntegration < Integration
  REST = "https://api.linkedin.com/rest".freeze
  API_VERSION = "202401".freeze
  CHANNELS = %w[linkedin].freeze

  class PublishError < StandardError; end

  before_validation { self.kind = :social }

  # ── config accessors ────────────────────────────────────────────────────────
  %w[access_token refresh_token token_expires_at label].each do |field|
    define_method(field) { config[field] }
    define_method("#{field}=") { |v| config[field] = v }
  end

  # Connected once we hold an access token from the OAuth consent.
  def configured?
    access_token.present?
  end

  # ── discovery (populates the region's organization dropdown) ────────────────

  ORG_PAGE_SIZE = 100
  ORG_MAX_PAGES = 20 # safety cap (2000 orgs) so a bad `total` can't loop forever

  # Organizations this member can post to as an administrator:
  # [{ "id" => "123", "name" => "Acme" }, ...]. `id` is the bare org id (no
  # urn:li:organization: prefix). Pages through the ACL list so a member who
  # administers more than one page of orgs still sees them all.
  def organizations
    orgs = []
    start = 0
    ORG_MAX_PAGES.times do
      res = rest_get("#{REST}/organizationAcls", {
        q: "roleAssignee", role: "ADMINISTRATOR", state: "APPROVED",
        start: start, count: ORG_PAGE_SIZE,
        projection: "(elements*(organization~(id,localizedName)))"
      })
      elements = Array(res["elements"])
      orgs.concat(elements.filter_map do |el|
        org = el["organization~"]
        org && { "id" => org["id"].to_s, "name" => org["localizedName"] }
      end)
      break if elements.size < ORG_PAGE_SIZE

      start += ORG_PAGE_SIZE
    end
    orgs
  rescue PublishError
    []
  end

  # ── publishing (target organization supplied by the caller) ─────────────────

  # Publish an organic post to an Organization page. `images` is an ordered array
  # of { data:, content_type: } — one for a single-image post, many for a native
  # multi-image post. Returns the created post URN.
  def publish_organization_post(org_id:, images:, caption:)
    raise PublishError, "No LinkedIn organization selected" if org_id.blank?
    raise PublishError, "LinkedIn posts need at least one image" if images.blank?

    author = "urn:li:organization:#{org_id}"
    image_urns = images.map { |img| upload_image(author, img[:data], img[:content_type]) }

    content =
      if image_urns.size == 1
        { "media" => { "id" => image_urns.first } }
      else
        { "multiImage" => { "images" => image_urns.map { |urn| { "id" => urn } } } }
      end

    create_post(author, content, caption)
  end

  # Verifies the connection by listing the member's admin organizations (no
  # posting). Powers the generic integration "Test" action.
  def deliver!(_message = nil, _recipient = nil)
    raise "Connect LinkedIn first" unless configured?

    { "verified" => true, "organizations" => organizations.size }
  end

  private

  # Upload one image via the Images API: initialize → PUT the bytes to the
  # returned upload URL → hand back the image URN to reference in a post.
  def upload_image(author, data, content_type)
    init = rest_post("#{REST}/images?action=initializeUpload",
                     { "initializeUploadRequest" => { "owner" => author } })
    value = init["value"] or raise PublishError, "No upload URL returned by LinkedIn"
    upload_url = value["uploadUrl"]
    urn = value["image"] or raise PublishError, "No image URN returned by LinkedIn"

    resp = Faraday.put(upload_url) do |req|
      req.headers["Authorization"] = "Bearer #{valid_access_token!}"
      req.headers["Content-Type"] = content_type.presence || "application/octet-stream"
      req.body = data
    end
    raise PublishError, "Image upload failed: #{resp.status}" unless resp.success?

    urn
  end

  def create_post(author, content, caption)
    body = {
      "author" => author,
      "commentary" => escape_commentary(caption.to_s),
      "visibility" => "PUBLIC",
      "distribution" => {
        "feedDistribution" => "MAIN_FEED", "targetEntities" => [], "thirdPartyDistributionChannels" => []
      },
      "content" => content,
      "lifecycleState" => "PUBLISHED",
      "isReblogDisabledByAuthor" => false
    }
    resp = rest_raw_post("#{REST}/posts", body)
    raise PublishError, "Post failed: #{resp.status} #{resp.body}" unless resp.success?

    # The created post URN comes back in a response header, not the body.
    resp.headers["x-restli-id"] || resp.headers["x-linkedin-id"] or
      raise PublishError, "No post id returned by LinkedIn"
  end

  # LinkedIn's Posts API treats a set of characters as reserved in `commentary`
  # (they drive mentions/hashtags/formatting); a literal one must be escaped with
  # a backslash or the request is rejected.
  RESERVED_COMMENTARY = /([\\|{}@\[\]()<>#*_~])/
  def escape_commentary(text)
    text.gsub(RESERVED_COMMENTARY, '\\\\\1')
  end

  # Returns a non-expired access token, refreshing in place when it's about to
  # lapse and we hold a refresh token. Falls back to the current token if no
  # refresh token is stored (e.g. the app isn't approved for offline access yet).
  def valid_access_token!
    return access_token if refresh_token.blank?
    return access_token if token_expires_at.present? && Time.parse(token_expires_at) > 5.minutes.from_now

    tokens = SocialOauth::Linkedin.refresh(refresh_token)
    tokens["refresh_token"] ||= refresh_token
    update!(config: config.merge(tokens))
    access_token
  end

  # ── HTTP helpers ────────────────────────────────────────────────────────────

  def default_headers
    {
      "Authorization" => "Bearer #{valid_access_token!}",
      "LinkedIn-Version" => API_VERSION,
      "X-Restli-Protocol-Version" => "2.0.0"
    }
  end

  def rest_get(url, query)
    resp = Faraday.get(url, query, default_headers)
    handle(resp, url)
  end

  def rest_post(url, body)
    handle(rest_raw_post(url, body), url)
  end

  def rest_raw_post(url, body)
    Faraday.post(url) do |req|
      default_headers.each { |k, v| req.headers[k] = v }
      req.headers["Content-Type"] = "application/json"
      req.body = body.to_json
    end
  end

  def handle(response, url)
    return JSON.parse(response.body.presence || "{}") if response.success?

    raise PublishError, "LinkedIn error (#{url}): #{response.status} #{response.body}"
  end
end
