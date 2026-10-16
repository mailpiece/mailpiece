require "test_helper"

class ActiveStorageAuthorizationTest < ActionDispatch::IntegrationTest
  HTML = %(<turbo-frame id="posts"><script>alert(1)</script></turbo-frame>)

  # Posts

  # A mail client loads a test email's images with no session.
  test "unauthenticated user can view blob attached to a draft" do
    blob = attach_to_post_body(create_unattached_blob)

    get rails_blob_path(blob, disposition: :inline)
    assert_response :redirect
    assert_match %r{rails/active_storage}, response.location

    get rails_storage_proxy_path(blob)
    assert_response :success
  end

  test "unauthenticated user can view blob attached to a scheduled post" do
    blob = attach_to_post_body(create_unattached_blob, posts(:scheduled))

    get rails_storage_proxy_path(blob)
    assert_response :success
  end

  test "unauthenticated user can view blob left only in a draft's revision" do
    blob = create_unattached_blob
    posts(:draft).revisions.create! title: "Before", body: "<p>#{ActionText::Attachment.from_attachable(blob).to_html}</p>"

    get rails_blob_path(blob.reload, disposition: :inline)
    assert_response :redirect
    assert_match %r{rails/active_storage}, response.location
  end

  test "unauthenticated user can view blob attached to a published post" do
    blob = attach_to_post_body(create_unattached_blob, posts(:sent))

    get rails_blob_path(blob, disposition: :inline)
    assert_response :redirect
    assert_match %r{rails/active_storage}, response.location
  end

  test "unauthenticated user can view blob attached to a sent email-only post" do
    blob = attach_to_post_body(create_unattached_blob, posts(:email_only))

    get rails_storage_proxy_path(blob)
    assert_response :success
  end

  test "unauthenticated user can view representation of a blob attached to a published post" do
    blob = attach_to_post_body(create_unattached_blob, posts(:sent))

    get rails_representation_path(blob.representation(resize_to_limit: [ 100, 100 ]))
    assert_response :redirect
    assert_match %r{rails/active_storage}, response.location
  end

  test "unauthenticated user can view blob left only in a published post's revision" do
    blob = create_unattached_blob
    posts(:sent).revisions.create! title: "Before", body: "<p>#{ActionText::Attachment.from_attachable(blob).to_html}</p>"

    get rails_blob_path(blob.reload, disposition: :inline)
    assert_response :redirect
    assert_match %r{rails/active_storage}, response.location
  end

  test "blob is not served on a url with no account in it" do
    blob = attach_to_post_body(create_unattached_blob, posts(:sent))

    untenanted do
      get rails_blob_path(blob, disposition: :inline)
      assert_redirected_to session_menu_path
    end
  end

  test "unauthenticated user can view logo" do
    blob = attach_logo_to(accounts(:davids_account))

    get rails_blob_path(blob, disposition: :inline)
    assert_response :redirect
    assert_match %r{rails/active_storage}, response.location
  end

  test "unauthenticated user can view logo thumbnail" do
    blob = attach_logo_to(accounts(:davids_account))

    get rails_representation_path(blob.representation(resize_to_fill: [ 256, 256 ]))
    assert_response :redirect
    assert_match %r{rails/active_storage}, response.location
  end

  # Subscriber imports

  test "unauthenticated user cannot download import file" do
    blob = create_import_blob_for(users(:mia))

    get rails_blob_path(blob, disposition: :attachment)
    assert_response :redirect
    assert_match %r{/session/new}, response.location
  end

  test "import's creator cannot download its file" do
    blob = create_import_blob_for(users(:mia))

    sign_in_as :mia

    get rails_blob_path(blob, disposition: :attachment)
    assert_response :forbidden

    get rails_storage_proxy_path(blob)
    assert_response :forbidden
  end

  # Forbidden, not sent to sign in: the token was read.
  test "bearer token cannot download import file" do
    blob = create_import_blob_for(users(:mia))

    get rails_blob_path(blob, disposition: :attachment), env: api_token_env
    assert_response :forbidden
  end

  # ActiveStorage::VariantRecord defines neither predicate.
  test "blob attached to a record that says nothing is private" do
    blob = attach_to_post_body(create_unattached_blob, posts(:sent))
    variant_blob = blob.variant(resize_to_limit: [ 100, 100 ]).processed.image.blob

    get rails_blob_path(variant_blob, disposition: :inline)
    assert_response :redirect
    assert_match %r{/session/new}, response.location

    sign_in_as :mia

    get rails_blob_path(variant_blob, disposition: :inline)
    assert_response :forbidden
  end

  test "user of the blob's account can view unattached blob" do
    blob = create_unattached_blob

    sign_in_as :nonstaff

    get rails_blob_path(blob, disposition: :inline)
    assert_response :redirect
    assert_match %r{rails/active_storage}, response.location
  end

  test "bearer token of the blob's account can view unattached blob" do
    blob = create_unattached_blob

    get rails_blob_path(blob, disposition: :inline), env: api_token_env
    assert_response :redirect
    assert_match %r{rails/active_storage}, response.location

    get rails_blob_path(blob, disposition: :inline), env: readonly_api_token_env
    assert_response :redirect
    assert_match %r{rails/active_storage}, response.location
  end

  test "bearer token of the blob's account can view representation of an unattached blob" do
    blob = create_unattached_blob

    get rails_representation_path(blob.representation(resize_to_limit: [ 100, 100 ])), env: api_token_env
    assert_response :redirect
    assert_match %r{rails/active_storage}, response.location
  end

  test "user of another account cannot view unattached blob" do
    blob = create_unattached_blob

    sign_in_as :other_admin

    get rails_blob_path(blob, disposition: :inline)
    assert_response :forbidden
  end

  test "unauthenticated user cannot view unattached blob" do
    blob = create_unattached_blob

    get rails_blob_path(blob, disposition: :inline)
    assert_response :redirect
    assert_match %r{/session/new}, response.location
  end

  # set_representation runs @blob.representation(...).processed, the libvips parser.
  # A forbidden or unauthenticated request must never reach it.
  test "unauthenticated user does not run the representation parser on an unattached blob" do
    blob = create_unattached_blob
    representation_path = rails_representation_path(blob.representation(resize_to_limit: [ 100, 100 ]))
    proxy_path = rails_storage_proxy_path(blob.representation(resize_to_limit: [ 100, 100 ]))

    ActiveStorage::Blob.any_instance.expects(:representation).never

    get representation_path
    assert_response :redirect
    assert_match %r{/session/new}, response.location

    get proxy_path
    assert_response :redirect
    assert_match %r{/session/new}, response.location
  end

  test "user of another account does not run the representation parser on an unattached blob" do
    blob = create_unattached_blob
    representation_path = rails_representation_path(blob.representation(resize_to_limit: [ 100, 100 ]))
    proxy_path = rails_storage_proxy_path(blob.representation(resize_to_limit: [ 100, 100 ]))

    sign_in_as :other_admin

    ActiveStorage::Blob.any_instance.expects(:representation).never

    get representation_path
    assert_response :forbidden

    get proxy_path
    assert_response :forbidden
  end

  test "proxy for unattached blob does not set public Cache-Control" do
    blob = create_unattached_blob

    sign_in_as :nonstaff

    get rails_storage_proxy_path(blob)
    assert_response :success
    assert_not_includes response.headers["Cache-Control"], "public"
  end

  test "proxy for blob attached to a published post sets public Cache-Control" do
    blob = attach_to_post_body(create_unattached_blob, posts(:sent))

    get rails_storage_proxy_path(blob)
    assert_response :success
    assert_includes response.headers["Cache-Control"], "public"
  end

  # Turbo's FetchResponse#isHTML renders each of these as HTML in a frame.
  %w[
    text/html;charset=utf-8
    text/html,foo
    text/x-html
    text/html+json
    text/vnd.turbo-stream.html
    application/xhtml+xml+xxe
    TEXT/HTML
    text/htmlé
    image/svg+xml
  ].each do |declared_type|
    test "blob declared #{declared_type} is served as octet-stream" do
      blob = attach_to_post_body(create_unattached_blob(content_type: declared_type, body: HTML), posts(:sent))

      get rails_storage_proxy_path(blob)

      assert_response :success
      assert_equal "application/octet-stream", response.media_type
      assert_match %r{attachment}, response.headers["Content-Disposition"].to_s
    end
  end

  test "unattached html blob is served as octet-stream to its own account" do
    blob = create_unattached_blob(content_type: "text/x-html", body: HTML)

    sign_in_as :nonstaff

    get rails_storage_proxy_path(blob)

    assert_response :success
    assert_equal "application/octet-stream", response.media_type
    assert_match %r{attachment}, response.headers["Content-Disposition"].to_s
  end

  test "image is still served inline with its own type" do
    blob = attach_to_post_body(create_unattached_blob, posts(:sent))

    get rails_storage_proxy_path(blob)

    assert_response :success
    assert_equal "image/jpeg", response.media_type
  end

  private
    # As a direct upload does: the declared content type is stored verbatim.
    def create_unattached_blob(content_type: "image/jpeg", body: file_fixture("moon.jpg").binread)
      blob = ActiveStorage::Blob.create_before_direct_upload! \
        filename: "upload",
        content_type: content_type,
        byte_size: body.bytesize,
        checksum: OpenSSL::Digest::MD5.base64digest(body)
      blob.upload_without_unfurling(StringIO.new(body))
      blob
    end

    def attach_to_post_body(blob, post = posts(:draft))
      post.update! body: "<p>#{ActionText::Attachment.from_attachable(blob).to_html}</p>"
      blob.reload
    end

    def attach_logo_to(account)
      account.avatar.attach io: file_fixture("moon.jpg").open, filename: "logo.jpg", content_type: "image/jpeg"
      account.avatar.blob
    end

    def create_import_blob_for(user)
      import = Subscriber::Import.create! account: user.account, creator: user, file: fixture_file_upload("subscribers.csv", "text/csv")
      import.file.blob
    end
end
