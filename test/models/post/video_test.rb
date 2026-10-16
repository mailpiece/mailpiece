require "test_helper"

class Post::VideoTest < ActiveSupport::TestCase
  LARGEST = "https://img.youtube.com/vi/dQw4w9WgXcQ/maxresdefault.jpg"
  DEFAULT = "https://img.youtube.com/vi/dQw4w9WgXcQ/hqdefault.jpg"

  test "from is the video a paragraph is only a link to, with the link's address and text" do
    { %(<p><a href="https://www.youtube.com/watch?v=dQw4w9WgXcQ">https://www.youtube.com/watch?v=dQw4w9WgXcQ</a></p>) => "dQw4w9WgXcQ",
      %(<p><a href="https://youtube.com/watch?t=42&amp;v=dQw4w9WgXcQ">Watch</a></p>) => "dQw4w9WgXcQ",
      %(<p><a href="http://m.youtube.com/shorts/a-b_c1D2e3F">My video</a><br></p>) => "a-b_c1D2e3F",
      %(<p><a href="https://youtu.be/dQw4w9WgXcQ?t=42">My video</a></p>) => "dQw4w9WgXcQ" }.each do |html, id|
      paragraph = Nokogiri::HTML5.fragment(html).at_css("p")
      video = Post::Video.from(paragraph)

      assert_equal [ id, paragraph.at_css("a")["href"], paragraph.at_css("a").text ], [ video.id, video.address, video.caption ], html
    end
  end

  test "from is nil for a paragraph that is no video" do
    [ %(<p>Watch <a href="https://youtu.be/dQw4w9WgXcQ">this</a> first.</p>),
      %(<p><a href="https://youtu.be/dQw4w9WgXcQ">this</a><br>Do watch it.</p>),
      %(<p>https://youtu.be/dQw4w9WgXcQ</p>),
      %(<p><a href="https://youtu.be/dQw4w9WgXcQx">x</a></p>),
      %(<p><a href="https://youtube.com.example.org/watch?v=dQw4w9WgXcQ">x</a></p>),
      %(<p><a href="https://www.youtube.com/playlist?list=dQw4w9WgXcQ">x</a></p>),
      %(<p><a href="https://example.org/watch?v=dQw4w9WgXcQ">x</a></p>) ].each do |html|
      assert_nil Post::Video.from(Nokogiri::HTML5.fragment(html).at_css("p")), html
    end
  end

  test "thumbnail_address is the picture every video has" do
    assert_equal DEFAULT, video.thumbnail_address
  end

  test "download_thumbnail takes the largest picture" do
    stub_request(:get, LARGEST).to_return(status: 200, body: "large", headers: { "Content-Type" => "image/jpeg" })

    assert_equal "large", video.download_thumbnail
  end

  test "download_thumbnail falls back to the picture every video has where there is no larger one" do
    stub_request(:get, LARGEST).to_return(status: 404)
    stub_request(:get, DEFAULT).to_return(status: 200, body: "default", headers: { "Content-Type" => "image/jpeg" })

    assert_equal "default", video.download_thumbnail
  end

  test "download_thumbnail has nothing for a video YouTube has no picture of" do
    stub_request(:get, LARGEST).to_return(status: 404)
    stub_request(:get, DEFAULT).to_return(status: 404)

    assert_nil video.download_thumbnail
  end

  test "download_thumbnail takes an image only, follows no redirect, and asks for no other picture after an answer that is no 404" do
    [ { status: 200, body: "<html>", headers: { "Content-Type" => "text/html" } },
      { status: 302, headers: { "Location" => "https://example.org/picture.jpg" } },
      { status: 503 } ].each do |answer|
      stub_request(:get, LARGEST).to_return(answer)

      assert_nil video.download_thumbnail
    end

    assert_not_requested :get, DEFAULT
  end

  test "download_thumbnail has nothing when the picture is too large or YouTube cannot be reached" do
    stub_request(:get, LARGEST).to_return(status: 200, body: "x" * (Post::Video::MAX_THUMBNAIL_SIZE + 1), headers: { "Content-Type" => "image/jpeg" })
    assert_nil video.download_thumbnail

    [ Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EHOSTUNREACH, SocketError, OpenSSL::SSL::SSLError ].each do |error|
      stub_request(:get, LARGEST).to_raise(error)

      assert_nil video.download_thumbnail, error.name
    end
  end

  test "download_thumbnail raises what nobody expected" do
    stub_request(:get, LARGEST).to_raise(RuntimeError)

    assert_raises(RuntimeError) { video.download_thumbnail }
  end

  private
    def video
      Post::Video.new id: "dQw4w9WgXcQ", address: "https://youtu.be/dQw4w9WgXcQ", caption: "A video"
    end
end
