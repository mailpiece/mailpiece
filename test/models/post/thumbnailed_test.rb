require "test_helper"

class Post::ThumbnailedTest < ActiveSupport::TestCase
  LARGEST = "https://img.youtube.com/vi/dQw4w9WgXcQ/maxresdefault.jpg"
  DEFAULT = "https://img.youtube.com/vi/dQw4w9WgXcQ/hqdefault.jpg"

  test "a save asks for the thumbnails the post does not hold, and for nothing when there are none to fetch" do
    assert_no_enqueued_jobs only: Post::FetchVideoThumbnailsJob do
      posts(:draft).update! body: "<p>No video here.</p>"
    end

    assert_enqueued_with job: Post::FetchVideoThumbnailsJob, args: [ posts(:draft) ] do
      posts(:draft).update! body: video
    end

    hold_thumbnail

    assert_no_enqueued_jobs only: Post::FetchVideoThumbnailsJob do
      posts(:draft).update! body: "<p>More.</p>#{video}"
    end
  end

  test "fetch_video_thumbnails_now keeps a copy of the largest picture, named for its video" do
    posts(:draft).update! body: "#{video}<aside data-audience=\"email\">#{video}</aside>"
    stub = stub_request(:get, LARGEST).to_return(status: 200, body: file_fixture("moon.jpg").binread, headers: { "Content-Type" => "image/jpeg" })

    posts(:draft).fetch_video_thumbnails_now

    assert_requested stub, times: 1
    assert_equal [ "dQw4w9WgXcQ.jpg" ], posts(:draft).reload.video_thumbnails.map { it.filename.to_s }
    assert_equal file_fixture("moon.jpg").binread, posts(:draft).video_thumbnail(video_of("dQw4w9WgXcQ")).download
    assert_predicate posts(:draft).video_thumbnail(video_of("dQw4w9WgXcQ")), :publicly_accessible?
  end

  test "fetch_video_thumbnails_now falls back to the picture every video has" do
    posts(:draft).update! body: video
    stub_request(:get, LARGEST).to_return(status: 404)
    stub_request(:get, DEFAULT).to_return(status: 200, body: file_fixture("moon.jpg").binread, headers: { "Content-Type" => "image/jpeg" })

    posts(:draft).fetch_video_thumbnails_now

    assert posts(:draft).video_thumbnail(video_of("dQw4w9WgXcQ"))
  end

  test "fetch_video_thumbnails_now asks YouTube for nothing the post holds" do
    posts(:draft).update! body: video
    hold_thumbnail

    posts(:draft).fetch_video_thumbnails_now

    assert_not_requested :get, LARGEST
    assert_equal 1, posts(:draft).reload.video_thumbnails.count
  end

  test "fetch_video_thumbnails_now leaves the post without a thumbnail it cannot have, and raises nothing" do
    posts(:draft).update! body: %(#{video}<p><a href="https://youtu.be/a-b_c1D2e3F">Another</a></p>)
    stub_request(:get, LARGEST).to_timeout
    stub_request(:get, "https://img.youtube.com/vi/a-b_c1D2e3F/maxresdefault.jpg").to_return(status: 200, body: file_fixture("moon.jpg").binread, headers: { "Content-Type" => "image/jpeg" })

    assert_nothing_raised { posts(:draft).fetch_video_thumbnails_now }

    assert_nil posts(:draft).video_thumbnail(video_of("dQw4w9WgXcQ"))
    assert posts(:draft).video_thumbnail(video_of("a-b_c1D2e3F"))
  end

  test "the job fetches the post's thumbnails" do
    posts(:draft).update! body: video
    stub = stub_request(:get, LARGEST).to_return(status: 200, body: file_fixture("moon.jpg").binread, headers: { "Content-Type" => "image/jpeg" })

    Post::FetchVideoThumbnailsJob.perform_now(posts(:draft))

    assert_requested stub
  end

  test "queue_deliveries_now fetches what is still missing before the issue is mailed, and mails it whatever comes of that" do
    posts(:draft).update! body: video
    posts(:draft).deliver
    stub = stub_request(:get, LARGEST).to_timeout

    assert_enqueued_jobs 1, only: Post::DeliveryJob do
      posts(:draft).queue_deliveries_now
    end

    assert_requested stub
  end

  test "queue_deliveries_now mails the issue even when keeping a thumbnail fails for a reason nobody expected" do
    posts(:draft).update! body: video
    posts(:draft).deliver
    stub_request(:get, LARGEST).to_raise(RuntimeError)

    assert_enqueued_jobs 1, only: Post::DeliveryJob do
      posts(:draft).queue_deliveries_now
    end
  end

  test "the job raises what nobody expected" do
    posts(:draft).update! body: video
    stub_request(:get, LARGEST).to_raise(RuntimeError)

    assert_raises(RuntimeError) { Post::FetchVideoThumbnailsJob.perform_now(posts(:draft)) }
  end

  test "a thumbnail goes with its post" do
    posts(:draft).update! body: video
    hold_thumbnail

    assert_difference -> { ActiveStorage::Attachment.count }, -1 do
      posts(:draft).destroy!
    end
  end

  test "excerpt reads no text in a paragraph that is a video" do
    posts(:sent).update! body: "<p>Hello.</p>#{video}<p>Bye.</p>"

    assert_equal "Hello. Bye.", posts(:sent).excerpt
  end

  private
    def video
      %(<p><a href="https://youtu.be/dQw4w9WgXcQ">https://youtu.be/dQw4w9WgXcQ</a></p>)
    end

    def video_of(id)
      Post::Video.new id: id, address: "https://youtu.be/#{id}", caption: "A video"
    end

    def hold_thumbnail
      posts(:draft).video_thumbnails.attach io: file_fixture("moon.jpg").open, filename: "dQw4w9WgXcQ.jpg", content_type: "image/jpeg"
    end
end
