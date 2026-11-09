require "test_helper"

class Public::PostsControllerTest < ActionDispatch::IntegrationTest
  test "index shows the newsletter's description as it was written" do
    accounts(:davids_account).update!(description: "<p>Notes on <strong>paperwork</strong>.</p>")

    get root_path

    assert_match "<strong>paperwork</strong>", response.body
  end

  test "the bare address belongs to no newsletter" do
    untenanted do
      get root_path
      assert_redirected_to session_menu_path
    end

    with_multi_tenant_mode(false) do
      untenanted do
        get root_path
        assert_redirected_to session_menu_path
      end
    end
  end

  test "index lists what is published and listed, without a session" do
    get root_path

    assert_response :success
    assert_match posts(:sent).title, response.body
    assert_match "public", response.headers["Cache-Control"]

    %i[ draft scheduled unlisted email_only other_accounts ].each do |post|
      assert_no_match posts(post).title, response.body
    end
  end

  test "index and show offer the subscribe form only while the account can send" do
    get root_path
    assert_match subscription_form, response.body

    account_senders(:davids).update!(from_address: nil)

    [ root_path, public_post_path(posts(:sent).public_param) ].each do |path|
      get path

      assert_response :success
      assert_no_match subscription_form, response.body
      assert_match public_feed_path, response.body
    end
  end

  test "index renders for an account with no sender" do
    account_senders(:davids).destroy

    get root_path

    assert_response :success
    assert_no_match subscription_form, response.body
  end

  test "index with the welcome on" do
    get root_path

    assert_response :success
    assert_no_match "Let me read it first", response.body

    accounts(:davids_account).start_welcoming

    get root_path

    assert_response :success
    assert_match "public", response.headers["Cache-Control"]
    assert_match "Let me read it first", response.body
  end

  test "index with a welcome message" do
    accounts(:davids_account).update!(description: "<p>Notes on paperwork.</p>", welcome_message: "<p>Paperwork, <strong>explained</strong>.</p>")

    get root_path

    assert_no_match "explained", response.body

    accounts(:davids_account).start_welcoming

    get root_path

    assert_match "Paperwork, <strong>explained</strong>.", response.body

    accounts(:davids_account).update!(welcome_message: "")

    get root_path

    assert_no_match "explained", response.body
  end

  test "index with the welcome on and no sender" do
    accounts(:davids_account).start_welcoming
    account_senders(:davids).update!(from_address: nil)

    get root_path

    assert_response :success
    assert_no_match "Let me read it first", response.body
  end

  test "index sends a signed-in user to the landing page, uncached" do
    sign_in_as :nonstaff

    get root_path

    assert_redirected_to landing_path
    assert_no_match "public", response.headers["Cache-Control"]
  end

  test "index as a feed" do
    get public_feed_path

    assert_response :success
    assert_equal "application/atom+xml", response.media_type
    assert_includes response.body, posts(:sent).title

    %i[ draft scheduled unlisted email_only other_accounts ].each do |post|
      assert_not_includes response.body, posts(post).title
    end
  end

  test "show" do
    get public_post_path(posts(:sent).public_param)

    assert_response :success
    assert_nil response.headers["X-Robots-Tag"]
  end

  test "show links a post's picture to its full size" do
    blob = ActiveStorage::Blob.create_and_upload! io: file_fixture("moon.jpg").open, filename: "moon.jpg", content_type: "image/jpeg"
    posts(:sent).update! body: "<p>Look.</p>#{ActionText::Attachment.from_attachable(blob).to_html}"

    get public_post_path(posts(:sent).public_param)

    assert_response :success
    assert_match "/rails/active_storage/representations/", response.body
  end

  test "an unlisted post's page keeps it out of search engines" do
    get public_post_path(posts(:unlisted).public_param)

    assert_select "meta[name=robots][content=noindex]"
  end

  test "a title cannot close the tag that describes the post" do
    posts(:sent).update! title: "</script><script>alert(1)</script> & <b>"

    get public_post_path(posts(:sent).reload.public_param)

    assert_response :success
    assert_no_match "</script><script>alert(1)", response.body
  end

  test "show an unlisted post at its address, kept out of search engines" do
    get public_post_path(posts(:unlisted).public_param)

    assert_response :success
    assert_equal "noindex", response.headers["X-Robots-Tag"]
  end

  test "show redirects an address whose title has changed since" do
    get public_post_path("an-older-title-#{posts(:sent).code}")

    assert_redirected_to public_post_path(posts(:sent).public_param)
    assert_response :moved_permanently
  end

  test "show as Markdown, under a front matter" do
    posts(:sent).update! title: %(Three "deadlines": March), body: "<h2>First</h2><p>File the <strong>form</strong>.</p>"

    get public_post_markdown_path(posts(:sent).public_param)

    assert_response :success
    assert_equal "text/markdown", response.media_type
    assert_match "public", response.headers["Cache-Control"]
    assert_nil response.headers["X-Robots-Tag"]
    assert_includes response.headers["Link"], public_post_url(posts(:sent).public_param)

    front_matter = YAML.safe_load(response.body[/\A---\n(.*?)\n---\n/m, 1], permitted_classes: [ Time ])
    assert_equal %(Three "deadlines": March), front_matter["title"]
    assert_equal posts(:sent).published_at.utc.iso8601, front_matter["date"].utc.iso8601
    assert_equal public_post_url(posts(:sent).public_param), front_matter["url"]

    assert_includes response.body, %(# Three "deadlines": March)
    assert_includes response.body, "## First"
    assert_includes response.body, "**form**"
    assert_no_match(/<html|<p>/, response.body)
  end

  test "show an unlisted post as Markdown, kept out of search engines" do
    get public_post_markdown_path(posts(:unlisted).public_param)

    assert_response :success
    assert_equal "noindex", response.headers["X-Robots-Tag"]
  end

  test "show as Markdown redirects an address whose title has changed since, to Markdown" do
    get public_post_markdown_path("an-older-title-#{posts(:sent).code}")

    assert_redirected_to public_post_markdown_path(posts(:sent).public_param)
    assert_response :moved_permanently
  end

  test "a post without a page has no Markdown either" do
    %i[ draft scheduled email_only other_accounts ].each do |post|
      get public_post_markdown_path(posts(post).public_param)

      assert_response :not_found
    end
  end

  test "a post's summary is on its page and on its card" do
    posts(:sent).update! summary: "On ladders"

    get public_post_path(posts(:sent).public_param)
    assert_match "On ladders", response.body

    get root_path
    assert_match "On ladders", response.body
  end

  test "md is the only extension an address takes, and a slug holds no dot" do
    assert_match %r{#{accounts(:davids_account).slug}/#{posts(:sent).public_param}\.md\z}, public_post_markdown_path(posts(:sent).public_param)

    get "#{public_post_path(posts(:sent).public_param)}.txt"
    assert_response :not_found

    get public_post_path(posts(:sent).public_param).sub(posts(:sent).slug, "v1.2-notes")
    assert_response :not_found

    posts(:sent).update! title: "Notes on README.md"
    get public_post_path("notes-on-readme-md-#{posts(:sent).code}")
    assert_response :success
  end

  test "an email-only post has no page, sent or not, even at a stale address" do
    get public_post_path(posts(:email_only).public_param)
    assert_response :not_found

    get public_post_path("an-older-title-#{posts(:email_only).code}")
    assert_response :not_found
  end

  test "a post gets its page when it stops being email only" do
    posts(:email_only).update! visibility: "unlisted"

    get public_post_path(posts(:email_only).public_param)

    assert_response :success
  end

  test "a draft or a scheduled post is not found" do
    get public_post_path(posts(:draft).public_param)
    assert_response :not_found

    get public_post_path(posts(:scheduled).public_param)
    assert_response :not_found
  end

  test "a post of another account is not found" do
    get public_post_path(posts(:other_accounts).public_param)
    assert_response :not_found
  end

  test "a cancelled account is not found" do
    accounts(:davids_account).create_cancellation!(initiated_by: users(:leo))

    get public_post_path(posts(:sent).public_param)

    assert_response :not_found
  end

  test "show draws what is only on the web, and nothing of what is only in the email" do
    write_for_each_audience_into posts(:sent)

    get public_post_path(posts(:sent).public_param)

    assert_response :success
    assert_includes response.body, "Subscribe on the site."
    assert_not_includes response.body, "Reply to this email."
    assert_not_includes response.body, "data-audience"
  end

  test "show as Markdown draws what is only on the web, and nothing of what is only in the email" do
    write_for_each_audience_into posts(:sent)

    get public_post_markdown_path(posts(:sent).public_param)

    assert_response :success
    assert_includes response.body, "Subscribe on the site."
    assert_not_includes response.body, "Reply to this email."
  end

  test "index as a feed draws what is only on the web, and nothing of what is only in the email" do
    write_for_each_audience_into posts(:sent)

    get public_feed_path

    assert_response :success
    assert_includes response.body, "Subscribe on the site."
    assert_not_includes response.body, "Reply to this email."
    assert_not_includes response.body, "data-audience"
  end

  test "show and the feed draw a paragraph that is only a YouTube link as its thumbnail over the link's text, from YouTube until the post holds a copy" do
    posts(:sent).update! body: %(<p>Before</p><p><a href="https://youtu.be/dQw4w9WgXcQ">My &lt;video&gt;</a></p>)

    get public_post_path(posts(:sent).public_param)
    assert_includes response.body, "https://youtu.be/dQw4w9WgXcQ"
    assert_includes response.body, "https://img.youtube.com/vi/dQw4w9WgXcQ/hqdefault.jpg"
    assert_includes response.body, "My &lt;video&gt;"

    get public_feed_path
    assert_includes response.body, "https://img.youtube.com/vi/dQw4w9WgXcQ/hqdefault.jpg"

    posts(:sent).video_thumbnails.attach io: file_fixture("moon.jpg").open, filename: "dQw4w9WgXcQ.jpg", content_type: "image/jpeg"

    get public_post_path(posts(:sent).public_param)
    assert_includes response.body, %(src="http://www.example.com#{posts(:sent).account.slug}/rails/active_storage/blobs/proxy/)
    assert_not_includes response.body, "img.youtube.com"

    get public_feed_path
    assert_includes response.body, "/rails/active_storage/blobs/proxy/"
    assert_not_includes response.body, "img.youtube.com"
  end

  test "show as Markdown keeps a YouTube link as it was written" do
    posts(:sent).update! body: %(<p><a href="https://youtu.be/dQw4w9WgXcQ">My video</a></p>)

    get public_post_markdown_path(posts(:sent).public_param)

    assert_includes response.body, "[My video](https://youtu.be/dQw4w9WgXcQ)"
  end

  private
    def subscription_form
      %(action="#{public_subscription_path}")
    end

    def write_for_each_audience_into(post)
      post.update! body: %(<p>Hello.</p><aside data-audience="email"><p>Reply to this email.</p></aside><aside data-audience="web"><p>Subscribe on the site.</p></aside>)
    end
end
