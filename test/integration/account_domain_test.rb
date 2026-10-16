require "test_helper"

class AccountDomainTest < ActionDispatch::IntegrationTest
  DOMAIN = "boletin.example"

  setup do
    @account = accounts(:davids_account)
    @account.update!(domain: DOMAIN)
    @post = posts(:sent)
  end

  test "a newsletter's public pages answer at the root of its domain" do
    host! DOMAIN

    get "/"
    assert_response :success
    assert_select "a[href=?]", "/#{@post.public_param}"
    assert_select "link[rel=canonical][href=?]", "http://#{DOMAIN}/"
    assert_select "link[rel=manifest][href=?]", "/manifest.json"

    get "/manifest.json"
    assert_response :success

    get "/#{@post.public_param}"
    assert_response :success
    assert_select "link[rel=canonical][href=?]", "http://#{DOMAIN}/#{@post.public_param}"

    get "/feed"
    assert_response :success

    get "/subscription"
    assert_response :success
  end

  test "the app's own screens do not answer on a newsletter's domain" do
    sign_in_as :mia
    host! DOMAIN

    [ "/posts", "/account/settings", "/session/new", "/landing", "/service-worker.js",
      "/#{@account.external_account_id}/posts", "/#{@account.external_account_id}/" ].each do |path|
      get path

      assert_response :not_found, "#{path} should not answer on a newsletter's domain"
    end

    host! "www.example.com"
    get posts_path
    assert_response :success
  end

  test "a page asked at the app's address names the domain as canonical" do
    get root_path
    assert_response :success
    assert_select "link[rel=canonical][href=?]", "http://#{DOMAIN}/"
    assert_select "link[rel=manifest]"

    get public_post_path(@post.public_param)
    assert_select "link[rel=canonical][href=?]", "http://#{DOMAIN}/#{@post.public_param}"
  end

  test "a file that needs signing in is not found on the domain, which sets no cookie" do
    blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("private"), filename: "notes.txt", content_type: "text/plain")
    host! DOMAIN

    get rails_blob_path(blob, script_name: "")

    assert_response :not_found
    assert_nil response.headers["Set-Cookie"]
  end

  test "a session cookie the browser still holds is not resumed on the domain" do
    sign_in_as :mia
    session_cookie = cookies.get_cookie("session_token").raw

    get root_path, headers: { "Cookie" => session_cookie }
    assert_redirected_to landing_path

    host! DOMAIN
    get "/", headers: { "Cookie" => session_cookie }

    assert_response :success
    assert_select "a[href=?]", "/#{@post.public_param}"
    assert_nil response.headers["Set-Cookie"]
    assert_match "public", response.headers["Cache-Control"]
  end

  test "a newsletter's mail links to its domain" do
    subscriber = subscribers(:active)
    email = PostMailer.issue(@post, subscriber)
    html = email.html_part.body.to_s

    assert_equal "<http://#{DOMAIN}/subscriptions/#{subscriber.token}/unsubscribe>", email["List-Unsubscribe"].value
    assert_includes html, "http://#{DOMAIN}/#{@post.public_param}"
    assert_includes html, "http://#{DOMAIN}/subscriptions/#{subscriber.token}/unsubscribe"
    assert_no_match @account.slug, html
    assert_no_match @account.slug, email.text_part.body.to_s

    confirmation = SubscriberMailer.confirmation(subscribers(:unconfirmed), token: "token")
    assert_includes confirmation.text_part.body.to_s, "http://#{DOMAIN}/subscriptions/token/confirm"
  end

  test "the app's links to a reader's page lead to the domain" do
    sign_in_as :mia

    get edit_post_path(@post)
    assert_select "a[href=?]", "http://#{DOMAIN}/#{@post.public_param}"

    get account_settings_path
    assert_select "li.row a[href=?]", edit_account_domain_path, text: /Domain\s+#{DOMAIN}/
  end
end
