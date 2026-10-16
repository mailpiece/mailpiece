require "net/http"

# A paragraph that is only a link to a YouTube video: a reader sees the video's thumbnail over the link's text.
class Post::Video
  # YOUTUBE_ADDRESS in app/javascript/editor/video_thumbnail_node.js is this one: the two change together.
  ADDRESS = %r{\Ahttps?://(?:(?:www\.|m\.)?youtube\.com/(?:watch\?(?:[^#]*&)?v=|shorts/)|youtu\.be/)([A-Za-z0-9_-]{11})(?:[/?&#].*)?\z}

  THUMBNAIL_HOST = "img.youtube.com"
  LARGEST_THUMBNAIL = "maxresdefault"
  DEFAULT_THUMBNAIL = "hqdefault"
  THUMBNAIL_OPEN_TIMEOUT = 2.seconds
  THUMBNAIL_READ_TIMEOUT = 5.seconds
  MAX_THUMBNAIL_SIZE = 2.megabytes

  class ThumbnailTooLarge < StandardError; end

  attr_reader :id, :address, :caption

  class << self
    # Nil for a paragraph that is no video: its one element, a line break aside, has to be a link that holds
    # all its text and leads to a video.
    def from(paragraph)
      nodes = paragraph.element_children.reject { |node| node.name == "br" }

      if nodes.one? && nodes.first.name == "a" && nodes.first.text.strip == paragraph.text.strip
        if id = nodes.first["href"].to_s[ADDRESS, 1]
          new id: id, address: nodes.first["href"], caption: nodes.first.text.strip
        end
      end
    end

    def all_in(fragment)
      fragment.find_all("p").filter_map { |paragraph| from(paragraph) }
    end

    # Each video's paragraph gives way to what the block draws for it.
    def replace_each_in(source)
      source.css("p").each do |paragraph|
        if video = from(paragraph)
          paragraph.replace yield(video).to_s
        end
      end
    end
  end

  def initialize(id:, address:, caption:)
    @id, @address, @caption = id, address, caption
  end

  # The picture every video has, at YouTube.
  def thumbnail_address
    "https://#{THUMBNAIL_HOST}#{thumbnail_path(DEFAULT_THUMBNAIL)}"
  end

  # The largest picture there is, or the one every video has. Nil when YouTube gives none, gives something that
  # is no image, or cannot be reached; a redirect is not followed.
  def download_thumbnail
    [ LARGEST_THUMBNAIL, DEFAULT_THUMBNAIL ].each do |name|
      http.request_get(thumbnail_path(name)) do |response|
        return image_in(response) unless response.is_a?(Net::HTTPNotFound)
      end
    end

    nil
  rescue ThumbnailTooLarge, SocketError, Net::OpenTimeout, Net::ReadTimeout, Errno::ETIMEDOUT, Errno::ECONNREFUSED,
      Errno::EHOSTUNREACH, Errno::ECONNRESET, OpenSSL::SSL::SSLError
    nil
  end

  private
    def thumbnail_path(name)
      "/vi/#{id}/#{name}.jpg"
    end

    def http
      Net::HTTP.new(THUMBNAIL_HOST, Net::HTTP.https_default_port).tap do |http|
        http.use_ssl = true
        http.open_timeout = THUMBNAIL_OPEN_TIMEOUT
        http.read_timeout = THUMBNAIL_READ_TIMEOUT
      end
    end

    def image_in(response)
      if response.is_a?(Net::HTTPOK) && response.content_type.to_s.start_with?("image/")
        "".b.tap do |image|
          response.read_body do |chunk|
            image << chunk
            raise ThumbnailTooLarge if image.bytesize > MAX_THUMBNAIL_SIZE
          end
        end
      end
    end
end
