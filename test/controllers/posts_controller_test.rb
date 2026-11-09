require "test_helper"

class PostsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :mia
  end

  test "index" do
    get posts_path

    assert_response :success
    assert_select "li##{ActionView::RecordIdentifier.dom_id(posts(:draft))}"
    assert_select "li##{ActionView::RecordIdentifier.dom_id(posts(:sent))}"
    assert_select "li##{ActionView::RecordIdentifier.dom_id(posts(:other_accounts))}", count: 0
  end

  test "index turns the page" do
    11.times { |index| accounts(:davids_account).posts.create!(title: "Issue #{index}") }

    get posts_path
    assert_select "a.pagination-link[href=?]", posts_path(page: 2), count: 1

    get posts_path(page: 2)
    assert_response :success
    assert_select "a.pagination-link[href=?]", posts_path(page: 3), count: 0
  end

  test "index with no post at all offers to add one" do
    accounts(:davids_account).posts.destroy_all

    get posts_path

    assert_select ".blank-slate a[href=?]", new_post_path
    assert_select ".status-filter", count: 0
  end

  test "index as JSON lists what is ahead, the drafts newest first and then the scheduled posts, nothing published or sent" do
    newer_draft = accounts(:davids_account).posts.create!(title: "Still being written")

    get posts_path, as: :json

    assert_response :success
    assert_equal [ newer_draft.id, posts(:draft).id, posts(:scheduled).id ], response.parsed_body.pluck("id")
  end

  test "index as JSON gives no counts" do
    get posts_path, as: :json

    assert_response :success
    assert response.parsed_body.none? { it.key?("brought_subscribers_count") }
  end

  test "show as JSON" do
    get post_path(posts(:draft), format: :json)

    assert_response :success
    assert_equal posts(:draft).title, response.parsed_body["title"]
    assert_equal false, response.parsed_body["published"]
  end

  test "new" do
    get new_post_path
    assert_response :success
  end

  test "create" do
    assert_difference -> { accounts(:davids_account).posts.count }, +1 do
      post posts_path, params: { post: { title: "Subcontractors: who answers", body: "<p>The papers are asked for twice.</p>" } }
    end

    created = Post.last
    assert_redirected_to edit_post_path(created)
    assert_equal users(:mia), created.creator
    assert_equal "The papers are asked for twice.", created.body.to_plain_text
    assert created.draft?
  end

  test "create without a title saves a draft, listed as untitled" do
    assert_difference -> { Post.count }, +1 do
      post posts_path, params: { post: { title: "", body: "<p>Only a first line.</p>" } }
    end

    created = Post.order(:id).last
    assert_redirected_to edit_post_path(created)
    assert_nil created.title

    get posts_path
    assert_select "#post_#{created.id} .row__title", text: "Untitled"
  end

  test "create that does not save" do
    assert_no_difference -> { Post.count } do
      post posts_path, params: { post: { title: "The file", visibility: "nowhere" } }
    end

    assert_response :unprocessable_entity
  end

  test "create as JSON" do
    post posts_path, params: { title: "Through the API" }, as: :json

    assert_response :created
    assert_equal "Through the API", response.parsed_body["title"]
  end

  test "create as JSON keeps a box as it was written" do
    post posts_path, params: { title: "Through the API", body: %(<aside data-audience="web"><p>Subscribe on the site.</p></aside>) }, as: :json

    assert_response :created
    assert_equal [ "web", "Subscribe on the site." ], audience_box_in(Post.find(response.parsed_body["id"]).body.body.to_html)
    assert_equal [ "web", "Subscribe on the site." ], audience_box_in(response.parsed_body["body_html"])
  end

  test "edit" do
    get edit_post_path(posts(:draft))
    assert_response :success

    get edit_post_path(posts(:sent))
    assert_response :success
  end

  test "edit leads to the post's results, mailed or not" do
    [ posts(:sent), posts(:draft) ].each do |post|
      get edit_post_path(post)
      assert_select "a[href=?]", post_results_path(post), text: "Results"
    end
  end

  test "edit gives the editor a box as it was written" do
    posts(:draft).update! body: %(<aside data-audience="web"><p>Subscribe on the site.</p></aside>)

    get edit_post_path(posts(:draft))

    box = Nokogiri::HTML5.fragment(css_select("lexxy-editor").first["value"]).at_css("aside")
    assert_equal [ "web", "Subscribe on the site." ], [ box["data-audience"], box.text ]
  end

  test "edit offers a draft its release, a scheduled post its schedule and a cancel, and a published post neither" do
    get edit_post_path(posts(:draft))
    assert_select "button[formaction=?]", post_release_path(posts(:draft)), text: "Publish and send to 1 subscriber"

    get edit_post_path(posts(:unlisted))
    assert_select "button[formaction=?]", post_release_path(posts(:unlisted)), count: 0

    get edit_post_path(posts(:scheduled))
    assert_select "button[formaction=?]", post_schedule_path(posts(:scheduled)), text: "Schedule and send to 1 subscriber"
    assert_select "button[formaction=?]", post_release_path(posts(:scheduled)), count: 0
    assert_select "button[formaction][name=_method][value=delete]", text: "Cancel schedule"
  end

  test "edit asks before the main button mails the list, and not before it only publishes" do
    confirm = "Mail this to 1 subscriber now? An email that has gone out cannot be changed or sent again."

    get edit_post_path(posts(:draft))
    assert_select "button[data-turbo-confirm=?]", confirm, text: "Publish and send to 1 subscriber"

    get edit_post_path(posts(:unlisted))
    assert_select "button[data-turbo-confirm=?]", confirm, count: 0

    posts(:draft).update! visibility: "unlisted"
    get edit_post_path(posts(:draft))
    assert_select "button:not([data-turbo-confirm])", text: "Publish by link"
  end

  test "edit offers a published post its unpublishing, and no sending" do
    get edit_post_path(posts(:unlisted))

    assert_select "input[name=destination]", count: 0
    assert_select "button[formaction=?][name=_method][value=delete]", post_publication_path(posts(:unlisted)), text: "Unpublish"
  end

  test "edit offers an issue with no page one" do
    get edit_post_path(posts(:email_only))

    assert_select "button[formaction=?][name=_method][value=post]", post_publication_path(posts(:email_only)), text: "Publish on the web"
  end

  test "edit without confirmed subscribers offers no sending" do
    subscribers(:active).deactivate

    get edit_post_path(posts(:draft))
    assert_select "input[name=destination][value=web_and_email], input[name=destination][value=email]", count: 0
    assert_select "input[name=destination][value=web]"
    assert_select "button:not([data-turbo-confirm])", text: "Publish"
  end

  test "edit without a complete sender still releases a draft, and says why it is not mailed" do
    account_senders(:davids).update!(from_address: nil)

    get edit_post_path(posts(:draft))
    assert_select "input[name=destination][value=web_and_email], input[name=destination][value=email]", count: 0
    assert_select "button[formaction=?]", post_release_path(posts(:draft)), text: "Publish"
    assert_select "a", text: "Finish the settings"
  end

  test "update" do
    patch post_path(posts(:sent)), params: { post: { title: "Four deadlines in March", visibility: "unlisted" } }

    assert_redirected_to edit_post_path(posts(:sent))
    assert_equal "Four deadlines in March", posts(:sent).reload.title
    assert posts(:sent).unlisted?
  end

  test "edit asks a draft nothing about where it is read, and a new post neither" do
    get edit_post_path(posts(:draft))
    assert_select "input[name='post[visibility]']", count: 0

    get edit_post_path(posts(:scheduled))
    assert_select "input[name='post[visibility]']", count: 0

    get new_post_path
    assert_select "input[name='post[visibility]']", count: 0
  end

  test "edit lets a published post on the web be listed or kept to its link" do
    get edit_post_path(posts(:unlisted))
    assert_select "button:not([disabled])", text: "Listed"
    assert_select "button[disabled]", text: "By link only"

    get edit_post_path(posts(:sent))
    assert_select "button[disabled]", text: "Listed"

    get edit_post_path(posts(:email_only))
    assert_select "form[action=?]", post_listing_path(posts(:email_only)), count: 0
  end

  test "edit offers a test to a post that can still be mailed" do
    get edit_post_path(posts(:draft))
    assert_select "input[name=email_address][value=?]", "mia@example.com"
    assert_select "button[formaction=?]", post_test_delivery_path(posts(:draft)), text: "Send a test"

    get edit_post_path(posts(:scheduled))
    assert_select "button[formaction=?]", post_test_delivery_path(posts(:scheduled)), text: "Send a test"

    get edit_post_path(posts(:unlisted))
    assert_select "input[name=email_address]", count: 0

    get edit_post_path(posts(:sent))
    assert_select "input[name=email_address]", count: 0

    account_senders(:davids).update!(from_address: nil)
    get edit_post_path(posts(:draft))
    assert_select "input[name=email_address]", count: 0
  end

  test "show as JSON counts the subscribers the post brought" do
    subscribers(:active).update!(source_post: posts(:sent))

    get post_path(posts(:sent), format: :json)

    assert_equal 1, response.parsed_body["brought_subscribers_count"]
  end

  test "show as JSON says the visibility and gives an email-only post no public address" do
    get post_path(posts(:email_only), format: :json)

    assert_equal "email_only", response.parsed_body["visibility"]
    assert_not response.parsed_body.key?("public_url")
  end

  test "edit offers a date only to a post published on the web" do
    get edit_post_path(posts(:unlisted))
    assert_select "input[type=date][name='post[published_day]']"

    get edit_post_path(posts(:email_only))
    assert_select "[name='post[published_day]'], [name='post[published_hour]']", count: 0

    get edit_post_path(posts(:draft))
    assert_select "[name='post[published_day]'], [name='post[published_hour]']", count: 0
  end

  test "update corrects the date of a published post on the web, and nothing of its sending" do
    assert_no_enqueued_jobs do
      assert_no_changes -> { posts(:sent).reload.sent_at } do
        patch post_path(posts(:sent)), params: { post: { published_at: "2019-03-01T09:30" } }
      end
    end

    assert_redirected_to edit_post_path(posts(:sent))
    assert_equal Time.utc(2019, 3, 1, 9, 30), posts(:sent).reload.published_at
  end

  test "update takes the day and the hour of the editor as the date, on the hour" do
    patch post_path(posts(:sent)), params: { post: { published_day: "2019-03-01", published_hour: "9" } }

    assert_redirected_to edit_post_path(posts(:sent))
    assert_equal Time.zone.local(2019, 3, 1, 9), posts(:sent).reload.published_at
  end

  test "update with the day and the hour as the editor showed them keeps the date's minutes" do
    posts(:unlisted).update_columns published_at: Time.zone.local(2024, 5, 6, 7, 8, 9), dated_at: Time.zone.local(2024, 5, 6, 7, 8, 9)

    assert_no_changes -> { posts(:unlisted).reload.published_at } do
      patch post_path(posts(:unlisted)), params: { post: { title: "Workshop notes", published_day: "2024-05-06", published_hour: "7" } }
    end

    assert_redirected_to edit_post_path(posts(:unlisted))
    assert_equal "Workshop notes", posts(:unlisted).reload.title
  end

  test "update with the day and the hour of a date exactly on the hour keeps the date" do
    posts(:unlisted).update_columns published_at: Time.zone.local(2024, 5, 6, 7), dated_at: Time.zone.local(2024, 5, 6, 7)

    assert_no_changes -> { posts(:unlisted).reload.published_at } do
      patch post_path(posts(:unlisted)), params: { post: { title: "Workshop notes", published_day: "2024-05-06", published_hour: "7" } }
    end

    assert_redirected_to edit_post_path(posts(:unlisted))
    assert_equal "Workshop notes", posts(:unlisted).reload.title
  end

  test "update refuses a day left empty on a date exactly on the hour" do
    posts(:unlisted).update_columns published_at: Time.zone.local(2024, 5, 6, 7), dated_at: Time.zone.local(2024, 5, 6, 7)

    assert_no_changes -> { posts(:unlisted).reload.published_at } do
      patch post_path(posts(:unlisted)), params: { post: { published_day: "", published_hour: "7" } }
    end

    assert_response :unprocessable_entity
    assert_select ".error-explanation", text: /cannot be left empty/
  end

  test "update refuses a day left empty, and says why in the form" do
    assert_no_changes -> { posts(:unlisted).reload.published_at } do
      patch post_path(posts(:unlisted)), params: { post: { published_day: "", published_hour: "9" } }
    end

    assert_response :unprocessable_entity
    assert_select ".error-explanation", text: /cannot be left empty/
  end

  test "update refuses a date still to come or left empty, and says why in the form" do
    assert_no_changes -> { posts(:unlisted).reload.published_at } do
      patch post_path(posts(:unlisted)), params: { post: { title: "Workshop notes", published_at: 1.day.from_now.strftime("%Y-%m-%dT%H:%M") } }
      assert_response :unprocessable_entity
      assert_select ".error-explanation", text: /cannot be in the future/

      patch post_path(posts(:unlisted)), params: { post: { published_at: "" } }
      assert_response :unprocessable_entity
      assert_select ".error-explanation", text: /cannot be left empty/
    end

    assert_equal "Notes for the March workshop", posts(:unlisted).reload.title
  end

  test "update never gives a draft a date, nor changes an email-only post's" do
    patch post_path(posts(:draft)), params: { post: { title: "The file", published_at: "2019-03-01T09:30" } }
    assert_equal "The file", posts(:draft).reload.title
    assert posts(:draft).draft?

    assert_no_changes -> { posts(:email_only).reload.published_at } do
      patch post_path(posts(:email_only)), params: { post: { title: "By email", published_at: "2019-03-01T09:30" } }
    end
    assert_equal "By email", posts(:email_only).reload.title
  end

  test "update never takes a day and an hour for a draft, nor for an email-only post" do
    patch post_path(posts(:draft)), params: { post: { title: "The file", published_day: "2019-03-01", published_hour: "9" } }
    assert_equal "The file", posts(:draft).reload.title
    assert posts(:draft).draft?

    assert_no_changes -> { posts(:email_only).reload.published_at } do
      patch post_path(posts(:email_only)), params: { post: { title: "By email", published_day: "2019-03-01", published_hour: "9" } }
    end
    assert_equal "By email", posts(:email_only).reload.title
  end

  test "update saves the summary" do
    patch post_path(posts(:draft)), params: { post: { summary: "On ladders" } }
    assert_equal "On ladders", posts(:draft).reload.summary

    get post_path(posts(:draft), format: :json)
    assert_equal "On ladders", response.parsed_body["summary"]
  end

  test "update as JSON sets the visibility" do
    patch post_path(posts(:draft), format: :json), params: { visibility: "unlisted" }, as: :json

    assert_response :success
    assert posts(:draft).reload.unlisted?
  end

  test "update as JSON keeps a box as it was written" do
    patch post_path(posts(:draft), format: :json), params: { body: %(<aside data-audience="email"><p>Reply to this email.</p></aside>) }, as: :json

    assert_response :success
    assert_equal [ "email", "Reply to this email." ], audience_box_in(posts(:draft).reload.body.body.to_html)
    assert_equal [ "email", "Reply to this email." ], audience_box_in(response.parsed_body["body_html"])
  end

  test "body_html as JSON keeps an image attached when it is sent back" do
    post = posts(:draft)
    blob = ActiveStorage::Blob.create_and_upload!(io: file_fixture("moon.jpg").open, filename: "moon.jpg", content_type: "image/jpeg")
    post.update!(body: %(<p>Look.</p><action-text-attachment sgid="#{blob.attachable_sgid}"></action-text-attachment>))

    get post_path(post, format: :json)
    body_html = response.parsed_body["body_html"]

    assert_includes body_html, "action-text-attachment"
    assert_includes body_html, blob.attachable_sgid

    assert_no_enqueued_jobs only: ActiveStorage::PurgeJob do
      patch post_path(post, format: :json), params: { body: body_html }, as: :json
    end

    assert_response :success
    assert_includes post.reload.body.body.attachables, blob
    assert ActiveStorage::Blob.exists?(blob.id)
  end

  test "update from Save draft saves and stays in the editor" do
    patch post_path(posts(:draft)), params: { post: { title: "The file" }, auto_save: true }

    assert_redirected_to edit_post_path(posts(:draft))
    assert_equal "Saved", flash[:notice]
    assert_equal "The file", posts(:draft).reload.title
    assert posts(:draft).draft?
  end

  test "update that does not save goes nowhere, and says why in the editor" do
    patch post_path(posts(:draft)), params: { post: { title: "The file", visibility: "nowhere" } }

    assert_response :unprocessable_entity
    assert_select ".error-explanation", text: /Visibility/
    assert_equal "How to keep a contractor file", posts(:draft).reload.title
  end

  test "auto-save writes a draft" do
    patch post_path(posts(:draft)), params: { title: "The file", auto_save: true }, as: :json

    assert_response :success
    assert_equal "The file", posts(:draft).reload.title
  end

  test "auto-save onto a published post is refused" do
    patch post_path(posts(:sent)), params: { title: "Four deadlines in March", auto_save: true }, as: :json

    assert_response :unprocessable_entity
    assert_equal "Three deadlines in March", posts(:sent).reload.title
  end

  test "update from a draft's editor left open on a post published since changes nothing" do
    patch post_path(posts(:unlisted)), params: { post: { title: "An old draft", visibility: "listed" }, auto_save: true }

    assert_redirected_to edit_post_path(posts(:unlisted))
    assert_match "published since", flash[:alert]
    assert_equal "Notes for the March workshop", posts(:unlisted).reload.title
    assert posts(:unlisted).unlisted?
    assert_empty posts(:unlisted).revisions
  end

  test "destroy deletes a draft and goes back to the list" do
    assert_difference -> { Post.count }, -1 do
      delete post_path(posts(:draft))
    end

    assert_redirected_to posts_path
    assert_equal "Post deleted", flash[:notice]
    assert_empty Post::Revision.where(post_id: posts(:draft).id)
  end

  test "destroy deletes a mailed issue with its deliveries and links" do
    post = posts(:sent)

    assert_difference -> { Post.count }, -1 do
      delete post_path(post)
    end

    assert_redirected_to posts_path
    assert_empty Post::Delivery.where(post_id: post.id)
    assert_empty Post::Link.where(post_id: post.id)
  end

  test "destroy leaves the subscribers a post brought with no source post" do
    subscribers(:active).update!(source_post: posts(:sent))

    delete post_path(posts(:sent))

    assert_nil subscribers(:active).reload.source_post_id
  end

  test "destroy as JSON answers with no content" do
    delete post_path(posts(:draft), format: :json)

    assert_response :no_content
    assert_not Post.exists?(posts(:draft).id)
  end

  test "destroy of another account's post is not found" do
    assert_no_difference -> { Post.count } do
      delete post_path(posts(:other_accounts))
    end

    assert_response :not_found
  end

  test "a post of another account is not found" do
    get edit_post_path(posts(:other_accounts))
    assert_response :not_found

    patch post_path(posts(:other_accounts)), params: { post: { title: "Ours now" } }
    assert_response :not_found
  end

  test "members are refused" do
    sign_in_as :nonstaff

    get posts_path
    assert_response :forbidden

    assert_no_difference -> { Post.count } do
      post posts_path, params: { post: { title: "No" } }
    end
    assert_response :forbidden
  end

  private
    def audience_box_in(html)
      box = Nokogiri::HTML5.fragment(html).at_css("aside")
      [ box["data-audience"], box.text.strip ]
    end
end
