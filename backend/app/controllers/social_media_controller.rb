# Serves Social media (feed/reel/carousel files) with a Content-Length and real
# byte ranges. Active Storage's own proxy streams through ActionController::Live,
# which drops Content-Length: Cloudflare then caches a lengthless copy and
# answers every Range request with the whole file as a 200. Safari will neither
# play a <video> nor show its first frame without 206 responses.
class SocialMediaController < ActiveStorage::BaseController
  include ActiveStorage::SetBlob
  include ActiveStorage::DisableSession

  def show
    response.headers["Accept-Ranges"] = "bytes"
    range = single_range

    if range
      response.headers["Content-Range"] = "bytes #{range.begin}-#{range.end}/#{@blob.byte_size}"
      send_data @blob.download_chunk(range), status: :partial_content, **file_options
    else
      # ponytail: a multi-range or unsatisfiable Range gets the whole file (200), which HTTP allows.
      http_cache_forever public: true do
        response.headers["Content-Length"] = @blob.byte_size.to_s
        send_file_headers! file_options
        self.response_body = Enumerator.new { |out| @blob.download { |chunk| out << chunk } }
      end
    end
  end

  private

  def single_range
    return if request.headers["Range"].blank?

    ranges = Rack::Utils.get_byte_ranges(request.headers["Range"], @blob.byte_size)
    return unless ranges&.one?

    # A big range (e.g. `bytes=0-` on a long reel) gets its first chunk as a 206;
    # Content-Range says where it stops and the player asks for the rest.
    range = ranges.first
    range.begin..[range.end, range.begin + ActiveStorage.streaming_chunk_max_size - 1].min
  end

  def file_options
    { type: @blob.content_type_for_serving, filename: @blob.filename.sanitized,
      disposition: @blob.forced_disposition_for_serving || "inline" }
  end
end
