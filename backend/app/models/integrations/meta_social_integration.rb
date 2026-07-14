require 'net/http'
require 'json'

# A Meta credential: a Business system-user access token (+ app secret) that can
# reach every Page and Instagram account the Business owns. The publishing target
# (which Page / Instagram / ad account) lives on the region, not here — one
# credential serves many regions.
#
# `access_token` should be a non-expiring System-User token (Business Manager →
# Settings → Users → System Users → Generate token). A per-page token is minted
# from it on demand and cached. Graph-API Page posts do NOT auto-mirror to
# Instagram, so we publish to each channel explicitly.
class MetaSocialIntegration < Integration
  GRAPH = "https://graph.facebook.com/v21.0".freeze
  READY_POLL_ATTEMPTS = 20
  READY_POLL_SECONDS = 3
  CHANNELS = %w[facebook instagram].freeze

  class PublishError < StandardError; end

  before_validation { self.kind = :social }

  # ── config accessors ────────────────────────────────────────────────────────
  %w[access_token app_secret label].each do |field|
    define_method(field) { config[field] }
    define_method("#{field}=") { |v| config[field] = v }
  end

  # A token is all that's needed to list Pages and publish; the target Page/IG
  # lives on the region.
  def configured?
    access_token.present?
  end

  # ── discovery (populates the region's dropdowns) ────────────────────────────

  # Pages this token can publish to: [{ "id" =>, "name" => }, ...]. Spans the
  # Pages assigned to the system user plus those owned/managed by its Businesses.
  def pages
    collect_pages_with_ig.uniq { |p| p["id"] }.map { |p| { "id" => p["id"], "name" => p["name"] } }
  rescue PublishError
    []
  end

  # Ad accounts this token can use: [{ "id" =>, "name" => }, ...]. `id` is the
  # bare account_id (no act_ prefix).
  def ad_accounts
    res = graph_get("#{GRAPH}/me/adaccounts", fields: "account_id,name", limit: 200, token: access_token)
    Array(res["data"]).map { |a| { "id" => a["account_id"], "name" => a["name"] } }
  rescue PublishError
    []
  end

  # The IG business account linked to a Page: { "id" =>, "username" => } or nil.
  def instagram_for_page(page_id)
    return nil if page_id.blank?

    res = graph_get("#{GRAPH}/#{page_id}", fields: "instagram_business_account{id,username}", token: page_access_token(page_id))
    ig = res["instagram_business_account"]
    ig && { "id" => ig["id"], "username" => ig["username"] }
  rescue PublishError
    nil
  end

  # Every IG business account reachable by this token, across all the Pages it
  # manages: [{ "id" =>, "username" =>, "page_id" =>, "page_name" => }, ...]. A
  # business can link several IG accounts (one per Page), so this powers a picker
  # instead of auto-resolving the single account tied to one Page. `page_id` is
  # the Page whose token publishes to that IG account.
  def instagram_accounts
    by_ig = {}
    collect_pages_with_ig.each do |p|
      ig = p["instagram_business_account"] || p["connected_instagram_account"]
      next unless ig && ig["id"]

      by_ig[ig["id"]] ||= { "id" => ig["id"], "username" => ig["username"], "page_id" => p["id"], "page_name" => p["name"] }
    end
    by_ig.values
  rescue PublishError
    []
  end

  # ── publishing (target Page / IG supplied by the caller) ────────────────────

  # Publish an organic post to a Facebook Page. Returns the created FB post id.
  def publish_facebook(page_id:, media_url:, caption:, video:)
    raise PublishError, "No Facebook Page selected" if page_id.blank?

    token = page_access_token(page_id)
    if video
      res = graph_post("#{GRAPH}/#{page_id}/videos", file_url: media_url, description: caption.to_s, token: token)
      res["id"] or raise PublishError, "No video id returned by Meta"
    else
      res = graph_post("#{GRAPH}/#{page_id}/photos", url: media_url, caption: caption.to_s, published: "true", token: token)
      # /photos returns the photo id + post_id (the feed story); prefer the post.
      res["post_id"].presence || res["id"] or raise PublishError, "No post id returned by Meta"
    end
  end

  # Publish to an Instagram account (2-step: create container → poll until
  # FINISHED → publish). `media_url` for an image MUST be a JPEG (IG rejects other
  # formats — the caller converts). Returns the published IG media id.
  def publish_instagram(ig_user_id:, page_id:, media_url:, caption:, video:)
    raise PublishError, "No Instagram account selected" if ig_user_id.blank?

    token = page_access_token(page_id)
    container = if video
      graph_post("#{GRAPH}/#{ig_user_id}/media", media_type: "REELS", video_url: media_url, caption: caption.to_s, token: token)
    else
      graph_post("#{GRAPH}/#{ig_user_id}/media", image_url: media_url, caption: caption.to_s, token: token)
    end
    id = container["id"] or raise PublishError, "No IG container id returned"

    wait_until_ready(id, token)
    res = graph_post("#{GRAPH}/#{ig_user_id}/media_publish", creation_id: id, token: token)
    res["id"] or raise PublishError, "No published IG media id returned"
  end

  # Publish an ordered set of images as a native Facebook multi-photo (carousel)
  # Page post. Each photo is uploaded unpublished, then attached to one feed post.
  def publish_facebook_carousel(page_id:, media_urls:, caption:)
    raise PublishError, "No Facebook Page selected" if page_id.blank?
    raise PublishError, "A carousel needs at least two images" if media_urls.to_a.size < 2

    token = page_access_token(page_id)
    photo_ids = media_urls.map do |url|
      res = graph_post("#{GRAPH}/#{page_id}/photos", url: url, published: "false", token: token)
      res["id"] or raise PublishError, "No photo id returned for a carousel image"
    end

    params = { message: caption.to_s, token: token }
    photo_ids.each_with_index { |id, i| params["attached_media[#{i}]"] = { media_fbid: id }.to_json }
    res = graph_post("#{GRAPH}/#{page_id}/feed", params)
    res["id"] or raise PublishError, "No carousel post id returned"
  end

  # Publish an ordered set of images as a native Instagram carousel: a child
  # container per image, then a CAROUSEL container, then publish.
  def publish_instagram_carousel(ig_user_id:, page_id:, media_urls:, caption:)
    raise PublishError, "No Instagram account selected" if ig_user_id.blank?
    raise PublishError, "A carousel needs at least two images" if media_urls.to_a.size < 2

    token = page_access_token(page_id)
    children = media_urls.map do |url|
      res = graph_post("#{GRAPH}/#{ig_user_id}/media", image_url: url, is_carousel_item: "true", token: token)
      id = res["id"] or raise PublishError, "No IG carousel child id returned"
      wait_until_ready(id, token)
      id
    end

    container = graph_post("#{GRAPH}/#{ig_user_id}/media", media_type: "CAROUSEL",
                           children: children.join(","), caption: caption.to_s, token: token)
    id = container["id"] or raise PublishError, "No IG carousel container id returned"

    wait_until_ready(id, token)
    res = graph_post("#{GRAPH}/#{ig_user_id}/media_publish", creation_id: id, token: token)
    res["id"] or raise PublishError, "No published IG carousel id returned"
  end

  # A page-scoped access token, minted from the system token and cached.
  def page_access_token(page_id)
    Rails.cache.fetch("meta_page_token:#{id}:#{page_id}", expires_in: 1.hour) do
      res = graph_get("#{GRAPH}/#{page_id}", fields: "access_token", token: access_token)
      res["access_token"].presence || access_token
    end
  rescue PublishError
    access_token
  end

  # Verifies the token by listing Pages (no posting). Powers the "Test" action.
  def deliver!(_message = nil, _recipient = nil)
    raise "Add a system-user access token first" unless configured?

    res = graph_get("#{GRAPH}/me/accounts", fields: "id,name", limit: 5, token: access_token)
    { "verified" => true, "pages" => Array(res["data"]).size }
  end

  private

  # Reels/containers are processed asynchronously — wait for FINISHED. Images
  # occasionally report "not ready" briefly too, so poll for both.
  def wait_until_ready(container_id, token)
    READY_POLL_ATTEMPTS.times do
      res = graph_get("#{GRAPH}/#{container_id}", fields: "status_code", token: token)
      case res["status_code"]
      when "FINISHED" then return
      when "ERROR" then raise PublishError, "Instagram rejected the media (container ERROR)"
      end
      sleep READY_POLL_SECONDS
    end
    raise PublishError, "Instagram media wasn't ready in time"
  end

  # POST to the Graph API. Uses the system token unless a :token is given.
  def graph_post(url, params)
    token = params.delete(:token) || access_token
    params = params.merge(access_token: token)
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Post.new(uri.path)
    request.set_form_data(params.transform_values(&:to_s))
    handle(http.request(request), url)
  end

  def graph_get(url, query)
    token = query.delete(:token) || access_token
    uri = URI(url)
    uri.query = URI.encode_www_form(query.merge(access_token: token))
    handle(Net::HTTP.get_response(uri), url)
  end

  # GET an already-built URL (e.g. a paging.next cursor, which carries its own
  # access_token and query string).
  def graph_get_url(full_url)
    handle(Net::HTTP.get_response(URI(full_url)), full_url)
  end

  # GET an edge and follow paging.next, collecting every row (bounded so a
  # runaway cursor can't loop forever).
  def graph_paged(url, query)
    rows = []
    next_url = nil
    first = query.merge(limit: 200)
    10.times do
      res = next_url ? graph_get_url(next_url) : graph_get(url, first.dup)
      rows.concat(Array(res["data"]))
      next_url = res.dig("paging", "next")
      break if next_url.blank?
    end
    rows
  end

  # Every Page reachable by this token: those directly assigned to the system
  # user (me/accounts) plus every Page owned or managed by the Businesses it can
  # see. Businesses surface Pages (and therefore Instagram accounts) that
  # me/accounts alone omits. Each Page carries its linked IG account.
  def collect_pages_with_ig
    fields = "id,name,instagram_business_account{id,username},connected_instagram_account{id,username}"
    pages = graph_paged("#{GRAPH}/me/accounts", fields: fields)

    begin
      graph_paged("#{GRAPH}/me/businesses", fields: "id,name").each do |b|
        %w[owned_pages client_pages].each do |edge|
          pages.concat(graph_paged("#{GRAPH}/#{b['id']}/#{edge}", fields: fields))
        rescue PublishError
          next
        end
      end
    rescue PublishError
      # business_management may not be granted; the me/accounts Pages still stand.
    end

    pages
  end

  def handle(response, url)
    return JSON.parse(response.body) if response.is_a?(Net::HTTPSuccess)

    err = (JSON.parse(response.body)["error"] rescue {}) || {}
    msg = err["error_user_msg"].presence || err["message"].presence || response.body
    raise PublishError, "Meta error (#{url}): #{msg}"
  end
end
