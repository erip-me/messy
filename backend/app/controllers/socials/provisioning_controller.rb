require "net/http"

module Socials
  # Ingestion API for provisioning a region's day with content generated
  # elsewhere (e.g. Claude Code + the Higgsfield MCP). Authenticated by an
  # environment API key (the same mechanism other programmatic Messy endpoints
  # use) via ApiAuthentication, which sets @account/@environment. Assets are given
  # as URLs; the server downloads each and attaches it via Active Storage.
  #
  # See docs/SOCIALS_PROVISIONING_API.md for the contract + examples.
  class ProvisioningController < ApplicationController
    include ApiAuthentication

    class DownloadError < StandardError; end

    MAX_REDIRECTS = 5

    # POST /socials/provision
    def create
      region = find_region(params[:region])
      return render_error("Unknown region '#{params[:region]}'", :not_found) unless region

      date = parse_date(params[:date])
      return render_error("A valid ISO date (YYYY-MM-DD) is required") unless date

      alternatives = params[:alternatives]
      return render_error("At least one alternative is required") if alternatives.blank?

      post = region.social_posts.find_or_create_by!(post_date: date)
      # Re-provisioning replaces previously *generated* variants; manual uploads
      # made in the dashboard are left untouched.
      post.social_alternatives.generated.destroy_all if truthy(params[:replace])

      created = alternatives.map.with_index { |raw, i| build_alternative(post, raw, i) }

      render json: {
        success: true,
        data: { id: post.id, region: region.name, date: post.post_date, alternative_ids: created.map(&:id) }
      }, status: :created
    rescue DownloadError => e
      render_error("Asset download failed: #{e.message}")
    rescue ActiveRecord::RecordInvalid => e
      render_error(e.record.errors.full_messages.to_sentence)
    end

    private

    # Region identified by numeric id or (case-insensitive) name, within the
    # authenticated account and the API key's environment (account-level regions
    # with no environment are visible to any key).
    def find_region(identifier)
      return nil if identifier.blank?

      scope = @account.social_regions.where("environment_id IS NULL OR environment_id = ?", @environment&.id)
      if identifier.to_s.match?(/\A\d+\z/)
        scope.find_by(id: identifier)
      else
        scope.where("LOWER(name) = ?", identifier.to_s.downcase).first
      end
    end

    def build_alternative(post, raw, index)
      raw = raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw
      alt = post.social_alternatives.create!(
        source: :generated,
        position: (post.social_alternatives.maximum(:position) || -1) + 1,
        headline: raw["headline"], body: raw["body"],
        cta_label: raw["cta_label"], cta_url: raw["cta_url"]
      )
      attach_from_url(alt.feed_media, raw["feed_media_url"], "social-#{post.id}-#{index}-feed")
      attach_from_url(alt.reel_media, raw["reel_media_url"], "social-#{post.id}-#{index}-reel")
      Array(raw["carousel_media_urls"]).each_with_index do |url, i|
        attach_from_url(alt.carousel_media, url, "social-#{post.id}-#{index}-carousel-#{i}")
      end
      alt
    end

    # Downloads the URL and attaches the bytes. No-op for a blank URL (a variant
    # may carry only one of the two renders).
    def attach_from_url(attachment, url, basename)
      return if url.blank?

      body, content_type = download(url)
      ext = Rack::Mime::MIME_TYPES.invert[content_type] || File.extname(URI(url).path).presence || ".bin"
      attachment.attach(io: StringIO.new(body), filename: "#{basename}#{ext}", content_type: content_type)
    end

    # Delegates to SafeHttp, which blocks private/reserved addresses (SSRF),
    # re-validates every redirect hop, and caps the response size.
    def download(url)
      SafeHttp.fetch(url, max_redirects: MAX_REDIRECTS)
    rescue SafeHttp::Error => e
      raise DownloadError, e.message
    end

    def parse_date(str)
      Date.iso8601(str.to_s)
    rescue ArgumentError, TypeError
      nil
    end

    def truthy(value)
      ActiveModel::Type::Boolean.new.cast(value)
    end

    def render_error(message, status = :unprocessable_entity)
      render json: { success: false, error: message }, status: status
    end
  end
end
