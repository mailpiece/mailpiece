require "test_helper"

class PostMailerTest < ActionMailer::TestCase
  setup do
    @post = posts(:sent)
    @subscriber = subscribers(:active)
    @unsubscribe_path = "#{@post.account.slug}/subscriptions/#{@subscriber.token}/unsubscribe"
  end

  test "issue goes from the account's sender to the subscriber" do
    delivery = @post.deliveries.find_by!(subscriber: @subscriber)
    email = PostMailer.issue(@post, @subscriber, delivery: delivery)

    assert_equal [ @subscriber.email ], email.to
    assert_equal [ "leo@newsletter.example" ], email.from
    assert_equal @post.title, email.subject
    assert_equal "issue", email["X-Tags"].value
    assert_equal delivery.id, email["Idempotency-Key"].value
  end

  test "issue opens with the summary, hidden, so an inbox shows it beside the subject, and repeats it under the title" do
    assert_no_match "display: none", PostMailer.issue(@post, @subscriber).html_part.body.to_s

    @post.update! summary: "On ladders"
    email = PostMailer.issue(@post, @subscriber)
    html = Nokogiri::HTML5.fragment(email.html_part.body.to_s)

    assert_equal "On ladders", html.at_css("div[style*='display: none']").text
    assert_equal "On ladders", html.at_css("h1 + p").text
    assert_match "#{@post.title}\n\nOn ladders\n", email.text_part.body.to_s.gsub("\r\n", "\n")
  end

  test "issue of a delivery carries the same Message-ID every time it is built, from the row and the sender's domain" do
    delivery = @post.deliveries.find_by!(subscriber: @subscriber)
    first, second = 2.times.map { PostMailer.issue(@post, @subscriber, delivery: delivery).deliver_now }

    assert_equal "#{delivery.id}@newsletter.example", first.message_id
    assert_equal first.message_id, second.message_id
    assert_includes first.encoded, "Message-ID: <#{delivery.id}@newsletter.example>"
  end

  test "test_issue has a Message-ID of its own each time" do
    first, second = 2.times.map { PostMailer.test_issue(@post, "editor@example.com").deliver_now }

    assert first.message_id.present?
    assert_not_equal first.message_id, second.message_id
  end

  test "over the relay issue leaves with the newsletter's token" do
    send_mail_over :relay, RELAY_TOKEN: "newsletter_token"

    [ PostMailer.issue(@post, @subscriber), PostMailer.test_issue(@post, "editor@example.com") ].each do |email|
      assert_kind_of Relay::DeliveryMethod, email.delivery_method
      assert_equal({ url: "https://relay.example/messages", token: "newsletter_token" }, email.delivery_method.settings)
    end
  end

  test "over SMTP issue leaves from the sender with the install's sign-in and no token" do
    send_mail_over :smtp

    [ PostMailer.issue(@post, @subscriber), PostMailer.test_issue(@post, "editor@example.com") ].each do |email|
      assert_kind_of Smtp::DeliveryMethod, email.delivery_method
      assert_equal [ "leo@newsletter.example" ], email.from
      assert_equal "smtp.example", email.delivery_method.settings[:address]
      assert_equal "smtp_password", email.delivery_method.settings[:password]
      assert_not email.delivery_method.settings.key?(:token)
    end
  end

  test "issue and test_issue take replies at the sender's reply to address" do
    account_senders(:davids).update!(reply_to_address: "editor@newsletter.example")

    assert_equal [ "editor@newsletter.example" ], PostMailer.issue(@post, @subscriber).reply_to
    assert_equal [ "editor@newsletter.example" ], PostMailer.test_issue(@post, "editor@example.com").reply_to
  end

  test "issue has no Reply-To while the sender has no reply to address" do
    assert_nil PostMailer.issue(@post, @subscriber)["Reply-To"]
  end

  test "issue has the post in an HTML and a text part" do
    email = PostMailer.issue(@post, @subscriber)

    assert_includes email.html_part.body.to_s, "Three deadlines fall together in March."
    assert_includes email.text_part.body.to_s, "Three deadlines fall together in March."
  end

  test "issue carries the unsubscribe link in both parts and in the one-click header" do
    email = PostMailer.issue(@post, @subscriber)

    assert_includes email.html_part.body.to_s, @unsubscribe_path
    assert_includes email.text_part.body.to_s, @unsubscribe_path
    assert_match @unsubscribe_path, email["List-Unsubscribe"].value
    assert_equal "List-Unsubscribe=One-Click", email["List-Unsubscribe-Post"].value
  end

  test "issue asks in both parts whether the reader liked it, with links from its delivery's token" do
    freeze_time
    delivery = @post.deliveries.find_by!(subscriber: @subscriber)
    email = PostMailer.issue(@post, @subscriber, delivery: delivery)
    token = delivery.generate_token_for(:rating)

    [ CGI.unescapeHTML(email.html_part.body.to_s), email.text_part.body.to_s ].each do |body|
      %w[ liked disliked ].each do |choice|
        assert_includes body, "#{@post.account.slug}/rating/new?#{{ access_token: token, choice: choice }.to_query}"
      end
    end
    assert_includes email.html_part.body.to_s, "you liked this issue</a> or if"
    assert_includes email.text_part.body.to_s, "Tell me if you liked this issue:"
  end

  test "issue links to its own account with no account set" do
    Current.without_account do
      assert_includes PostMailer.issue(@post, @subscriber).text_part.body.to_s, @unsubscribe_path
    end
  end

  test "issue loads an image from an address in its own account" do
    blob = ActiveStorage::Blob.create_and_upload! io: file_fixture("moon.jpg").open, filename: "moon.jpg", content_type: "image/jpeg"
    @post.update!(body: "<p>#{ActionText::Attachment.from_attachable(blob).to_html}</p>")

    Current.without_account do
      assert_includes PostMailer.issue(@post, @subscriber).html_part.body.to_s, "#{@post.account.slug}/rails/active_storage/blobs/proxy/"
    end
  end

  test "test_issue of a draft loads an image from the address that needs no session" do
    blob = ActiveStorage::Blob.create_and_upload! io: file_fixture("moon.jpg").open, filename: "moon.jpg", content_type: "image/jpeg"
    posts(:draft).update!(body: "<p>#{ActionText::Attachment.from_attachable(blob).to_html}</p>")

    assert blob.reload.publicly_accessible?
    assert_includes PostMailer.test_issue(posts(:draft), "editor@example.com").html_part.body.to_s, "#{posts(:draft).account.slug}/rails/active_storage/blobs/proxy/"
  end

  test "issue shows an attached video as a linked block that leads to the post's page" do
    @post.update!(body: video_attachment_html)
    email = PostMailer.issue(@post, @subscriber)
    html = Nokogiri::HTML5.fragment(email.html_part.body.to_s)
    post_address = "#{@post.account.slug}/#{@post.public_param}"

    assert_equal 2, html.css("figure a").count { |link| link["href"].end_with?(post_address) }
    assert_equal "clip.mp4", html.at_css("figure > a > span").text
    assert_includes html.at_css("figure > a > span")["style"], "border"
    assert_equal "Watch the video", html.at_css("figure figcaption a").text
    assert_empty html.css("video")
    assert_match %r{\[clip\.mp4\]\(\S+#{Regexp.escape(post_address)}\)}, email.text_part.body.to_s
  end

  test "issue of an email-only post links an attached video to its file" do
    posts(:email_only).update!(body: video_attachment_html)
    email = PostMailer.issue(posts(:email_only), @subscriber)
    link = Nokogiri::HTML5.fragment(email.html_part.body.to_s).at_css("figure > a")

    assert_includes link["href"], "/rails/active_storage/blobs/proxy/"
    assert_match %r{\[clip\.mp4\]\(\S+/rails/active_storage/blobs/proxy/}, email.text_part.body.to_s
  end

  test "issue shows a paragraph that is only a YouTube link as its thumbnail" do
    {
      "https://www.youtube.com/watch?v=dQw4w9WgXcQ" => "dQw4w9WgXcQ",
      "https://youtube.com/watch?t=42&v=dQw4w9WgXcQ" => "dQw4w9WgXcQ",
      "https://youtu.be/dQw4w9WgXcQ?t=42" => "dQw4w9WgXcQ",
      "https://www.youtube.com/shorts/a-b_c1D2e3F" => "a-b_c1D2e3F"
    }.each do |address, id|
      @post.update!(body: %(<p>Before</p><p><a href="#{ERB::Util.html_escape(address)}">#{ERB::Util.html_escape(address)}</a></p>))
      email = PostMailer.issue(@post, @subscriber)
      html = Nokogiri::HTML5.fragment(email.html_part.body.to_s)
      image = html.at_css("figure > a > img")

      assert_equal "https://img.youtube.com/vi/#{id}/hqdefault.jpg", image["src"]
      assert_operator image["width"].to_i, :<=, PostMailerHelper::EMAIL_IMAGE_WIDTH
      assert_includes image["style"], "max-width: 100%"
      assert_equal address, image.parent["href"]
      assert_equal [ address, address ], html.at_css("figure figcaption a").then { [ it.text, it["href"] ] }
      assert_includes email.text_part.body.to_s, address
    end
  end

  test "issue shows the post's own copy of a YouTube thumbnail, and its text part keeps the link" do
    @post.update!(body: %(<p><a href="https://youtu.be/dQw4w9WgXcQ">My &lt;video&gt;</a></p>))
    @post.video_thumbnails.attach io: file_fixture("moon.jpg").open, filename: "dQw4w9WgXcQ.jpg", content_type: "image/jpeg"

    email = PostMailer.issue(@post, @subscriber)
    image = Nokogiri::HTML5.fragment(email.html_part.body.to_s).at_css("figure > a > img")

    assert_includes image["src"], "#{@post.account.slug}/rails/active_storage/blobs/proxy/"
    assert_equal "https://youtu.be/dQw4w9WgXcQ", image.parent["href"]
    assert_equal "My <video>", Nokogiri::HTML5.fragment(email.html_part.body.to_s).at_css("figure figcaption a").text
    assert_not_includes email.html_part.body.to_s, "Watch the video"
    assert_includes email.text_part.body.to_s, "https://youtu.be/dQw4w9WgXcQ"
  end

  test "issue keeps a YouTube link inside a sentence as a link" do
    @post.update!(body: %(<p>See <a href="https://youtu.be/dQw4w9WgXcQ">the recording</a> first.</p>))
    html = PostMailer.issue(@post, @subscriber).html_part.body.to_s

    assert_includes html, %(href="https://youtu.be/dQw4w9WgXcQ")
    assert_includes html, "the recording"
    assert_not_includes html, "img.youtube.com"
  end

  test "issue shows no thumbnail for an address that only looks like a YouTube video" do
    [ "https://youtu.be/dQw4w9WgXcQx", "https://youtu.be/short", "https://youtube.com.example.org/watch?v=dQw4w9WgXcQ",
      "https://www.youtube.com/playlist?list=dQw4w9WgXcQ", "https://example.org/watch?v=dQw4w9WgXcQ" ].each do |address|
      @post.update!(body: %(<p><a href="#{address}">#{address}</a></p>))

      assert_not_includes PostMailer.issue(@post, @subscriber).html_part.body.to_s, "img.youtube.com"
    end
  end

  test "issue opens with the newsletter's name beside the link to the web, then the date and the author" do
    html = Nokogiri::HTML5.fragment(PostMailer.issue(@post, @subscriber).html_part.body.to_s)
    name, web = html.css("table[role=presentation] td")

    assert_equal @post.account.name, name.text
    assert_includes name["style"], "Georgia"
    assert_includes web.at_css("a")["href"], @post.public_param
    assert_equal "#{I18n.l(@post.published_at.utc.to_date, format: :public_post)} · #{@post.creator.name}", html.at_css("table[role=presentation] + p").text
    assert_includes html.at_css("h1")["style"], "Georgia"
  end

  test "test_issue of a draft is dated today" do
    html = Nokogiri::HTML5.fragment(PostMailer.test_issue(posts(:draft), "editor@example.com").html_part.body.to_s)

    assert_includes html.at_css("table[role=presentation] + p").text, I18n.l(Time.current.utc.to_date, format: :public_post)
  end

  test "issue keeps the markup a mail client shows and drops the rest" do
    @post.update!(body: %(<h2>News</h2><p style="color: red" onclick="x()">Hello <a href="https://example.org">world</a></p>))

    html = PostMailer.issue(@post, @subscriber).html_part.body.to_s

    assert_includes html, %(href="https://example.org")
    assert_not_includes html, "color: red"
    assert_not_includes html, "onclick"
  end

  test "issue and test_issue of an email-only post link to no web page" do
    [ PostMailer.issue(posts(:email_only), @subscriber), PostMailer.test_issue(posts(:email_only), "editor@example.com") ].each do |email|
      assert_not_includes email.html_part.body.to_s, "View on the web"
      assert_not_includes email.text_part.body.to_s, "View on the web"
      assert_not_includes email.html_part.body.to_s, posts(:email_only).public_param
    end
  end

  test "test_issue is marked in the subject and carries no unsubscribe link" do
    email = PostMailer.test_issue(@post, "editor@example.com")

    assert_equal [ "editor@example.com" ], email.to
    assert_equal "[Test] #{@post.title}", email.subject
    assert_nil email["List-Unsubscribe"]
    assert_nil email["X-Tags"]
    assert_not_includes email.html_part.body.to_s, "/unsubscribe"
    assert_not_includes email.text_part.body.to_s, "/unsubscribe"
    assert_not_includes email.text_part.body.to_s, "/rating"
  end

  test "issue draws what is only in the email in both parts, and nothing of what is only on the web" do
    @post.update! body: %(<p>Hello.</p><aside data-audience="email"><p>Reply to this email.</p></aside><aside data-audience="web"><p>Subscribe on the site.</p></aside>)

    email = PostMailer.issue(@post, @subscriber)
    html, text = email.html_part.body.to_s, email.text_part.body.to_s

    [ html, text ].each do |part|
      assert_includes part, "Hello."
      assert_includes part, "Reply to this email."
      assert_not_includes part, "Subscribe on the site."
      assert_not_includes part, "data-audience"
      assert_not_includes part, "<aside"
    end
  end

  test "issue sends a recorded link through its redirect in both parts, and leaves the rest as written" do
    @post.update! body: %(<p><a href="https://forms.example.com/training">Sign up here</a>, read <a href="https://example.com/handbook/ladders">the handbook</a> or <a href="https://example.org/other">this</a>. <a href="mailto:leo@newsletter.example">Write</a>.</p>)

    email = PostMailer.issue(@post, @subscriber)
    html, text = email.html_part.body.to_s, email.text_part.body.to_s
    links = Nokogiri::HTML5.fragment(html).css("a").to_h { |link| [ link.text, link["href"] ] }

    assert_equal public_link_address("7k2m9qxa"), links["Sign up here"]
    assert_equal public_link_address("4d8w1zpc"), links["the handbook"]
    assert_equal "https://example.org/other", links["this"]
    assert_equal "mailto:leo@newsletter.example", links["Write"]
    assert_includes links["View on the web"], @post.public_param

    assert_includes text, "[Sign up here](#{public_link_address("7k2m9qxa")})"
    assert_includes text, "[the handbook](#{public_link_address("4d8w1zpc")})"
    assert_includes text, "[this](https://example.org/other)"
    assert_includes text, @unsubscribe_path

    [ html, text ].each do |part|
      assert_not_includes part, "https://forms.example.com/training"
      assert_not_includes part, "https://example.com/handbook/ladders"
    end
  end

  test "issue builds a redirect in its own account with no account set" do
    @post.update! body: %(<p><a href="https://forms.example.com/training">Sign up here</a></p>)

    Current.without_account do
      assert_includes PostMailer.issue(@post, @subscriber).html_part.body.to_s, %(href="#{public_link_address("7k2m9qxa")}")
    end
  end

  test "test_issue of a post not mailed keeps its links as written" do
    posts(:draft).update! body: %(<p><a href="https://forms.example.com/training">Sign up here</a></p>)

    email = PostMailer.test_issue(posts(:draft), "editor@example.com")

    assert_includes email.html_part.body.to_s, %(href="https://forms.example.com/training")
    assert_includes email.text_part.body.to_s, "[Sign up here](https://forms.example.com/training)"
    assert_not_includes email.html_part.body.to_s, "/link/"
    assert_not_includes email.text_part.body.to_s, "/link/"
  end

  test "issue still shows a recorded YouTube link as its thumbnail, and the thumbnail goes through the redirect" do
    @post.update! body: %(<p><a href="https://youtu.be/dQw4w9WgXcQ">https://youtu.be/dQw4w9WgXcQ</a></p>)
    @post.record_links
    address = public_link_address(@post.links.find_by!(original_url: "https://youtu.be/dQw4w9WgXcQ").code)

    email = PostMailer.issue(@post, @subscriber)
    html = Nokogiri::HTML5.fragment(email.html_part.body.to_s)

    assert_equal "https://img.youtube.com/vi/dQw4w9WgXcQ/hqdefault.jpg", html.at_css("figure > a > img")["src"]
    assert_equal [ address, address ], html.css("figure a").map { |link| link["href"] }
    assert_includes email.text_part.body.to_s, address
  end

  test "offline, issue carries each uploaded picture inline once, 600 pixels wide, and its other files attached" do
    image = ActiveStorage::Blob.create_and_upload! io: file_fixture("moon.jpg").open, filename: "moon.jpg", content_type: "image/jpeg"
    file = ActiveStorage::Blob.create_and_upload! io: StringIO.new("rules"), filename: "rules.txt", content_type: "text/plain", identify: false
    @post.update!(body: "<p>#{attachment_html(image)}</p><p>#{attachment_html(image)}</p>#{attachment_html(file)}")

    while_offline do
      Current.without_account do
        email = PostMailer.issue(@post, @subscriber)
        html = Nokogiri::HTML5.fragment(email.html_part.body.to_s)
        picture, attached = email.attachments.partition(&:inline?)

        assert_equal 1, picture.size
        assert_equal "image/jpeg", picture.first.mime_type
        assert_equal 600, Vips::Image.new_from_buffer(picture.first.decoded, "").width
        assert_equal [ picture.first.url ] * 2, html.css("figure > img").map { it["src"] }
        assert_equal [ "rules.txt" ], attached.map(&:filename)
        assert_includes html.text, "rules.txt"
        assert_empty html.css("a")
        assert_not_includes email.html_part.body.to_s, "http://example.com"
        assert_not_includes email.text_part.body.to_s, "http://example.com"
      end
    end
  end

  test "offline, issue shows an uploaded video with no preview by its name, leading nowhere" do
    ActiveStorage::Blob.any_instance.stubs(:previewable?).returns(false)
    @post.update!(body: video_attachment_html)

    while_offline do
      email = PostMailer.issue(@post, @subscriber)
      html = Nokogiri::HTML5.fragment(email.html_part.body.to_s)

      assert_includes html.css("p").map(&:text), "clip.mp4"
      assert_empty html.css("a")
      assert_empty email.attachments
      assert_includes email.text_part.body.to_s, "clip.mp4"
      assert_not_includes email.text_part.body.to_s, "http://example.com"
    end
  end

  test "offline, issue carries the post's copy of a YouTube thumbnail inline and still links to YouTube" do
    @post.update!(body: %(<p><a href="https://youtu.be/dQw4w9WgXcQ">My video</a></p>))
    @post.video_thumbnails.attach io: file_fixture("moon.jpg").open, filename: "dQw4w9WgXcQ.jpg", content_type: "image/jpeg"

    while_offline do
      email = PostMailer.issue(@post, @subscriber)
      image = Nokogiri::HTML5.fragment(email.html_part.body.to_s).at_css("figure > a > img")

      assert_equal email.attachments.sole.url, image["src"]
      assert email.attachments.sole.inline?
      assert_equal "https://youtu.be/dQw4w9WgXcQ", image.parent["href"]
    end
  end

  test "offline, issue leads straight where its links were written, asks for no rating and offers unsubscribing by reply" do
    account_senders(:davids).update!(reply_to_address: "editor@newsletter.example")
    @post.update! body: %(<p><a href="https://forms.example.com/training">Sign up here</a></p>)
    delivery = @post.deliveries.find_by!(subscriber: @subscriber)

    while_offline do
      email = PostMailer.issue(@post, @subscriber, delivery: delivery)
      html, text = email.html_part.body.to_s, email.text_part.body.to_s

      assert_equal "<mailto:editor@newsletter.example?subject=unsubscribe>", email["List-Unsubscribe"].value
      assert_nil email["List-Unsubscribe-Post"]
      assert_equal [ "https://forms.example.com/training" ], Nokogiri::HTML5.fragment(html).css("a").map { it["href"] }
      assert_includes text, "[Sign up here](https://forms.example.com/training)"

      [ CGI.unescapeHTML(html), text ].each do |part|
        assert_includes part, %(To unsubscribe, reply to this email with "unsubscribe".)
        assert_not_includes part, "View on the web"
        assert_not_includes part, "liked this issue"
        assert_not_includes part, "http://example.com"
      end
    end
  end

  private
    def public_link_address(code)
      "http://#{ActionMailer::Base.default_url_options[:host]}#{@post.account.slug}/link/#{code}"
    end

    def video_attachment_html
      blob = ActiveStorage::Blob.create_and_upload! io: StringIO.new("video"), filename: "clip.mp4", content_type: "video/mp4", identify: false
      attachment_html(blob)
    end

    def attachment_html(blob)
      ActionText::Attachment.from_attachable(blob).to_html
    end
end
