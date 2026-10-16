require "test_helper"

class Public::PostsControllerTest < ActionDispatch::IntegrationTest
  test "index shows the newsletter's description as it was written, and as plain text to a crawler" do
    accounts(:davids_account).update!(description: "<p>Notes on <strong>paperwork</strong>.</p>")

    get root_path

    assert_select ".newsletter-header__description strong", text: "paperwork"
    assert_select "meta[name=description][content=?]", "Notes on paperwork."
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
    assert_select "a[href=?]", public_post_path(posts(:sent).public_param)
    assert_match "public", response.headers["Cache-Control"]

    %i[ draft scheduled unlisted email_only other_accounts ].each do |post|
      assert_select "a[href=?]", public_post_path(posts(post).public_param), count: 0
    end
  end

  test "index and show offer the subscribe form only while the account can send" do
    get root_path
    assert_select "#subscribe form[action=?]", public_subscription_path

    account_senders(:davids).update!(from_address: nil)

    [ root_path, public_post_path(posts(:sent).public_param) ].each do |path|
      get path

      assert_response :success
      assert_select "#subscribe form", count: 0
      assert_select "#subscribe a[href=?]", public_feed_path
    end
  end

  test "index renders for an account with no sender" do
    account_senders(:davids).destroy

    get root_path

    assert_response :success
    assert_select "#subscribe form", count: 0
  end

  test "index with the welcome on" do
    get root_path

    assert_response :success
    assert_select "head script", text: /getItem\("welcome-/, count: 0
    assert_select "[data-controller~=welcome]", count: 0
    assert_select "button.welcome-skip", count: 0

    accounts(:davids_account).start_welcoming

    get root_path

    assert_response :success
    assert_match "public", response.headers["Cache-Control"]
    assert_select "head script[nonce]", text: /localStorage\.getItem\("welcome-1234567"\)/
    assert_select ".page[data-controller=welcome][data-welcome-key-value=?][data-action=?]", "welcome-1234567", "submit->welcome#remember" do
      assert_select "#subscribe form[action=?]", public_subscription_path, count: 1
      assert_select ".post-summaries a[href=?]", public_post_path(posts(:sent).public_param)
      assert_select "button.welcome-skip[type=button][data-action=?]", "welcome#dismiss", text: "Let me read it first"
    end
  end

  test "index with a welcome message" do
    accounts(:davids_account).update!(description: "<p>Notes on paperwork.</p>", welcome_message: "<p>Paperwork, <strong>explained</strong>.</p>")

    get root_path

    assert_select ".welcome-message", count: 0

    accounts(:davids_account).start_welcoming

    get root_path

    assert_select ".newsletter-header .newsletter-header__description", text: "Notes on paperwork."
    assert_select ".newsletter-header .welcome-message strong", text: "explained"

    accounts(:davids_account).update!(welcome_message: "")

    get root_path

    assert_select ".newsletter-header__description", text: "Notes on paperwork."
    assert_select ".welcome-message", count: 0
  end

  test "index with the welcome on and no sender" do
    accounts(:davids_account).start_welcoming
    account_senders(:davids).update!(from_address: nil)

    get root_path

    assert_response :success
    assert_select "head script", text: /getItem\("welcome-/, count: 0
    assert_select "[data-controller~=welcome]", count: 0
    assert_select "button.welcome-skip", count: 0
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
    assert_select "h1", text: posts(:sent).title
    assert_select "title", text: "#{posts(:sent).title} | #{accounts(:davids_account).name}"
    assert_select "meta[property='og:title'][content=?]", "#{posts(:sent).title} | #{accounts(:davids_account).name}"
    assert_nil response.headers["X-Robots-Tag"]
  end

  test "show carries what a shared link needs" do
    get public_post_path(posts(:sent).public_param)

    assert_select "link[rel=canonical][href=?]", public_post_url(posts(:sent).public_param)
    assert_select "link[rel=sitemap][href=?]", public_sitemap_url
    assert_select "meta[name=description][content=?]", posts(:sent).excerpt
    assert_select "meta[property='og:type'][content=article]"
    assert_select "meta[property='og:site_name'][content=?]", accounts(:davids_account).name
    assert_select "meta[property='og:url'][content=?]", public_post_url(posts(:sent).public_param)
    assert_select "meta[property='article:published_time'][content=?]", posts(:sent).published_at.utc.iso8601
    assert_select "meta[property='og:image']", count: 0
    assert_select "meta[name='twitter:card'][content=summary]"
  end

  test "show shares the post's first image as a large card" do
    posts(:sent).update! body: %(<p>Look.</p><action-text-attachment content-type="image/png" url="https://example.com/ladder.png" width="600" height="400"></action-text-attachment>)

    get public_post_path(posts(:sent).public_param)

    assert_select "meta[property='og:image'][content=?]", "https://example.com/ladder.png"
    assert_select "meta[name='twitter:card'][content=summary_large_image]"
  end

  test "show opens a post's picture in the lightbox, behind a link that works without it" do
    blob = ActiveStorage::Blob.create_and_upload! io: file_fixture("moon.jpg").open, filename: "moon.jpg", content_type: "image/jpeg"
    posts(:sent).update! body: "<p>Look.</p>#{ActionText::Attachment.from_attachable(blob).to_html}"

    get public_post_path(posts(:sent).public_param)

    assert_select "body[data-controller~=lightbox]" do
      assert_select "article.post a[data-lightbox-target=image][href*='/rails/active_storage/representations/'] img"
      assert_select "dialog.lightbox[data-lightbox-target=dialog][data-action~='close->lightbox#reset']" do
        assert_select "img[data-lightbox-target=zoomedImage]"
        assert_select "form[method=dialog] button"
      end
    end
  end

  test "an unlisted post still carries its share tags" do
    get public_post_path(posts(:unlisted).public_param)

    assert_select "meta[name=robots][content=noindex]"
    assert_select "meta[property='og:title']"
  end

  test "index carries the newsletter's share tags" do
    get root_path

    assert_select "link[rel=canonical][href=?]", root_url
    assert_select "meta[property='og:title'][content=?]", accounts(:davids_account).name
    assert_select "title", text: accounts(:davids_account).name
    assert_select "meta[property='og:type'][content=website]"
    assert_select "meta[name='twitter:card'][content=summary]"
  end

  test "show describes the post to a search engine" do
    get public_post_path(posts(:sent).public_param)

    data = structured_data
    assert_equal "https://schema.org", data["@context"]
    assert_equal "BlogPosting", data["@type"]
    assert_equal posts(:sent).title, data["headline"]
    assert_equal posts(:sent).excerpt, data["description"]
    assert_equal public_post_url(posts(:sent).public_param), data["url"]
    assert_equal public_post_url(posts(:sent).public_param), data["mainEntityOfPage"]
    assert_equal posts(:sent).published_at.utc.iso8601, data["datePublished"]
    assert_equal posts(:sent).updated_at.utc.iso8601, data["dateModified"]
    assert_equal({ "@type" => "Person", "name" => posts(:sent).creator.name }, data["author"])
    assert_equal({ "@type" => "Organization", "name" => accounts(:davids_account).name, "url" => root_url }, data["publisher"])
    assert_not data.key?("image")
  end

  test "show describes the post's first image to a search engine" do
    posts(:sent).update! body: %(<p>Look.</p><action-text-attachment content-type="image/png" url="https://example.com/ladder.png" width="600" height="400"></action-text-attachment>)

    get public_post_path(posts(:sent).public_param)

    assert_equal "https://example.com/ladder.png", structured_data["image"]
  end

  test "a title cannot close the tag that describes the post" do
    posts(:sent).update! title: "</script><script>alert(1)</script> & <b>"

    get public_post_path(posts(:sent).reload.public_param)

    assert_response :success
    assert_no_match "</script><script>alert(1)", response.body
    assert_select "script[type='application/ld+json']", count: 1
    assert_equal "</script><script>alert(1)</script> & <b>", structured_data["headline"]
  end

  test "index describes the newsletter to a search engine" do
    accounts(:davids_account).update!(description: "<p>Notes on <strong>paperwork</strong>.</p>")

    get root_path

    data = structured_data
    assert_equal "WebSite", data["@type"]
    assert_equal accounts(:davids_account).name, data["name"]
    assert_equal "Notes on paperwork.", data["description"]
    assert_equal root_url, data["url"]
    assert_not data.key?("headline")
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

  test "show advertises the post as Markdown" do
    get public_post_path(posts(:sent).public_param)

    assert_select "link[rel=alternate][type='text/markdown'][href=?]", public_post_markdown_url(posts(:sent).public_param)
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

  test "a post's summary is under its title, on its card and in its description, and nothing stands in for one" do
    get public_post_path(posts(:sent).public_param)
    assert_select ".post__summary", count: 0

    posts(:sent).update! summary: "On ladders"

    get public_post_path(posts(:sent).public_param)
    assert_select ".post__title + .post__summary", text: "On ladders"
    assert_select "meta[name=description][content=?]", "On ladders"

    get root_path
    assert_select "#post_#{posts(:sent).id} .post-summary__excerpt", text: "On ladders"
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
    assert_select "article .lexxy-content p", text: "Subscribe on the site."
    assert_select "article aside", count: 0
    assert_not_includes response.body, "Reply to this email."
    assert_select "meta[name=description][content=?]", "Hello. Subscribe on the site."
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
    assert_select "article .lexxy-content figure.video-thumbnail" do
      assert_select "a[href='https://youtu.be/dQw4w9WgXcQ'][target=_blank][rel=noopener]", count: 2
      assert_select "a.video-thumbnail__picture img[alt='Video on YouTube'][src=?]", "https://img.youtube.com/vi/dQw4w9WgXcQ/hqdefault.jpg"
      assert_select "figcaption a", text: "My <video>"
    end

    get public_feed_path
    assert_includes response.body, "https://img.youtube.com/vi/dQw4w9WgXcQ/hqdefault.jpg"

    posts(:sent).video_thumbnails.attach io: file_fixture("moon.jpg").open, filename: "dQw4w9WgXcQ.jpg", content_type: "image/jpeg"

    get public_post_path(posts(:sent).public_param)
    assert_select "a.video-thumbnail__picture img[src^='http'][src*=?]", "#{posts(:sent).account.slug}/rails/active_storage/blobs/proxy/"
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
    def structured_data
      JSON.parse css_select("script[type='application/ld+json']").sole.text
    end

    def write_for_each_audience_into(post)
      post.update! body: %(<p>Hello.</p><aside data-audience="email"><p>Reply to this email.</p></aside><aside data-audience="web"><p>Subscribe on the site.</p></aside>)
    end
end
