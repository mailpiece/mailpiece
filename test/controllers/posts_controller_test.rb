require "test_helper"

class PostsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :mia
  end

  test "index keeps the up hotkey off a crumb that leads out of the account" do
    users(:mia).identity.users.create! account: accounts(:other_account), name: "Elsewhere", role: :member

    get posts_path

    assert_select "a.breadcrumbs__home[href=?]:not([data-controller])", "/session/menu"
  end

  test "index" do
    get posts_path

    assert_response :success
    assert_select "li##{ActionView::RecordIdentifier.dom_id(posts(:draft))}"
    assert_select "li##{ActionView::RecordIdentifier.dom_id(posts(:other_accounts))}", count: 0
    assert_select ".header__actions a[href=?] + a[href=?]", snippets_path, journeys_path
    assert_select ".header__actions a[href=?] + a[href=?]", journeys_path, new_post_path
  end

  test "index lists the drafts and then what is scheduled, each under its heading, with no status beside a row" do
    get posts_path

    assert_select "h2.rows__heading + ul.rows", count: 2
    assert_equal %w[ Drafts Scheduled ], css_select("h2.rows__heading").map(&:text)
    assert_select "section.rows__section:nth-of-type(1) li##{ActionView::RecordIdentifier.dom_id(posts(:draft))}"
    assert_select "section.rows__section:nth-of-type(2) li##{ActionView::RecordIdentifier.dom_id(posts(:scheduled))}"
    assert_select "li .row__end .chip, li .separator--horizontal", count: 0
    assert_select "input[data-quick-find-target=input]"
  end

  test "index keeps what is published and sent to screens of their own, and counts each" do
    get posts_path

    assert_select "li##{ActionView::RecordIdentifier.dom_id(posts(:unlisted))}", count: 0
    assert_select "li##{ActionView::RecordIdentifier.dom_id(posts(:sent))}", count: 0
    assert_select "li.row:has(a[href=?]) .row__end", posts_published_path, text: "2"
    assert_select "li.row:has(a[href=?]) .row__end", posts_sent_path, text: "2"
  end

  test "index offers to search every post for what the filter did not find on the screen" do
    get posts_path

    assert_select ".filter__empty a[href=?][data-quick-find-target=searchLink]", search_path
  end

  test "index leaves out the group that has nothing in it" do
    posts(:scheduled).update_columns(scheduled_posting_at: nil, scheduled_delivery: false, dated_at: nil)

    get posts_path

    assert_equal %w[ Drafts ], css_select("h2.rows__heading").map(&:text)
    assert_select "li##{ActionView::RecordIdentifier.dom_id(posts(:scheduled))}"
  end

  test "index with nothing being written still offers a new post and what was released" do
    accounts(:davids_account).posts.drafts.destroy_all

    get posts_path

    assert_select ".blank-slate a[href=?]", new_post_path
    assert_select "li.row a[href=?]", posts_sent_path
  end

  test "index as JSON lists what the screen lists, the drafts and then what is scheduled" do
    get posts_path, as: :json

    assert_response :success
    assert_equal [ posts(:draft).id, posts(:scheduled).id ], response.parsed_body.pluck("id")
  end

  test "index as JSON gives no counts" do
    get posts_path, as: :json

    assert_response :success
    assert response.parsed_body.none? { it.key?("liked_count") || it.key?("brought_subscribers_count") }
  end

  test "index lists what is scheduled from the latest to the soonest, on the screen and as JSON" do
    posts(:draft).schedule(at: 2.days.from_now)

    get posts_path
    assert_equal [ posts(:draft), posts(:scheduled) ].map { |post| ActionView::RecordIdentifier.dom_id(post) }, css_select("section.rows__section li").pluck("id")

    get posts_path, as: :json
    assert_equal [ posts(:draft).id, posts(:scheduled).id ], response.parsed_body.pluck("id")
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

    get edit_post_path(created)
    assert_select ".breadcrumbs strong", text: "Untitled"
    assert_select "[name='post[title]']:not([required])"
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
      assert_select ".header__actions a[href=?]", post_results_path(post), text: "Results"
    end
  end

  test "new and edit offer the snippets under a slash, in the text" do
    get new_post_path
    assert_select "lexxy-editor lexxy-prompt[trigger='/'][name=snippet][insert-editable-text][src=?]", prompts_snippets_path

    get edit_post_path(posts(:sent))
    assert_select "lexxy-editor lexxy-prompt[trigger='/'][name=snippet][src=?]", prompts_snippets_path
  end

  test "edit gives the editor a box as it was written, and the name to put over each kind" do
    posts(:draft).update! body: %(<aside data-audience="web"><p>Subscribe on the site.</p></aside>)

    get edit_post_path(posts(:draft))

    box = Nokogiri::HTML5.fragment(css_select("lexxy-editor").first["value"]).at_css("aside")
    assert_equal [ "web", "Subscribe on the site." ], [ box["data-audience"], box.text ]
    assert_includes css_select("lexxy-editor").first["style"], %(--audience-web-label: "Only on the web")
    assert_includes css_select("lexxy-editor").first["style"], %(--audience-email-label: "Only in the email")
  end

  test "edit wires Enter in the title to the text, and the bar to the save's state" do
    get edit_post_path(posts(:draft))

    assert_select ".writing[data-controller~='post-bar'] form[data-controller~='advance-to-editor'][data-controller~='save-state'][data-controller~='auto-save']" do
      assert_select "[name='post[title]'][data-action~='keydown.enter->advance-to-editor#advance']"
      assert_select "[data-advance-to-editor-target=editor]"
      assert_select ".writing-bar .post-actions__state [data-save-state-target=label][role=status]", text: /Edited/
      assert_select ".writing-bar .post-actions__state", text: /\ADraft/
      assert_select "[data-save-state-target=label]", count: 1
    end

    assert_select "form[data-action~='auto-save:saving->save-state#saving'][data-action~='auto-save:saved->save-state#saved'][data-action~='auto-save:failed->save-state#failed']"
    assert_select "form[data-action~='keydown.meta+s@document->auto-save#submitNow'][data-save-state-dirty-value='Unsaved changes'][data-save-state-saved-value='Saved']"
  end

  test "edit keeps one main button, after a Save that only an unscheduled draft hides" do
    get edit_post_path(posts(:draft))
    assert_select ".writing-bar button[type=submit][hidden]", text: "Save"
    assert_equal "Save", css_select("form.writing__form button[type=submit]").first.text.strip
    assert_select "button.post-actions__primary[formaction='#{post_release_path(posts(:draft))}'][name=_method][value=post]", text: "Publish and send to 1 subscriber"
    assert_select "button.post-actions__primary[data-release-path='#{post_release_path(posts(:draft))}'][data-schedule-path='#{post_schedule_path(posts(:draft))}'][data-publication-path='#{post_publication_path(posts(:draft))}']"
    assert_select "button.btn.post-actions__beside[type=submit][name=button]:not([formaction])", text: "Save draft"

    get edit_post_path(posts(:unlisted))
    assert_select ".post-actions__split button.post-actions__primary[type=submit]:not([formaction])", text: "Save"
    assert_select "button[formaction='#{post_release_path(posts(:unlisted))}']", count: 0
    assert_select ".post-actions__state", text: /Unlisted/

    get edit_post_path(posts(:sent))
    assert_select ".post-actions__split button.post-actions__primary[type=submit]:not([formaction])", text: "Save"
    assert_select ".post-actions__split button.post-actions__more[data-action='dialog#toggle']"
    assert_select "dialog.post-pop", count: 1

    get edit_post_path(posts(:scheduled))
    assert_select "button.btn.post-actions__beside[type=submit]:not([hidden])[name=button]:not([formaction])", text: "Save"
    assert_equal "Save", css_select("form.writing__form button[type=submit]").first.text.strip
    assert_select "[data-controller=dialog] > .post-actions__split.post-actions__main" do
      assert_select "button.post-actions__primary[type=submit][formaction='#{post_schedule_path(posts(:scheduled))}'][name=_method][value=post][data-turbo-confirm='Schedule this to be mailed to 1 subscriber on the date picked?']", text: "Schedule and send to 1 subscriber"
      assert_select "button.post-actions__more[type=button][aria-label='Change the schedule'][data-action='dialog#toggle']"
    end
    assert_select "button[formaction][name=_method][value=delete]", text: "Cancel schedule"
  end

  test "edit draws the release choices closed, in a box of the app's own that the arrow opens" do
    get edit_post_path(posts(:draft))

    assert_select "form.writing__form .writing-bar[data-controller~='dialog-manager']" do
      assert_select "[data-controller=dialog][data-dialog-orient-value=false][data-action~='keydown.esc->dialog#close:stop'][data-action~='click@document->dialog#closeOnClickOutside']", count: 2 do
        assert_select "button.post-actions__more[type=button][data-action='dialog#toggle']"
        assert_select "dialog.popup.post-pop[data-dialog-target=dialog][data-action='post-bar:submitted->dialog#close']:not([open])", count: 2
      end
    end

    assert_select "dialog.post-pop--menu" do
      assert_equal %w[ web_and_email email web link ], css_select("input[type=radio][name=destination]").map { |radio| radio["value"] }
      assert_equal [ "On the web and by email", "By email only", "On the web only", "On the web, by link only" ], css_select("label.post-pop__item").map { |label| label.text.strip }
      assert_select "input[name=destination][value=web_and_email][checked][data-label='Publish and send to 1 subscriber'][data-confirm]"
      assert_select "input[name=destination][value=email][data-label='Send to 1 subscriber'][data-confirm]"
      assert_select "input[name=destination][value=web][data-label='Publish']:not([data-confirm])"
      assert_select "input[name=destination][value=link][data-label='Publish by link']:not([data-confirm])"
      assert_select "input[name=destination][data-action~='keydown.enter->dialog#close:prevent']", count: 4
      assert_select "button[type=button]", count: 0
      assert_select ".post-pop__heading", text: "When", count: 0
      assert_select "input[name=when]", count: 0
      assert_select "button[type=submit]", count: 0
    end
  end

  test "edit shows a draft its date as the hour now running, outside the post so no save keeps it" do
    get edit_post_path(posts(:draft))

    assert_select ".writing form.writing__form dialog.post-pop--menu" do
      assert_select ".post-pop__heading", text: "Publication date"
      assert_select ".post-pop__when input[type=date][name=day][aria-label='Day'][data-post-bar-target=day][data-action~='post-bar#choose']:not([min]):not([max])"
      assert_select ".post-pop__when input[name=day][value=?]", Time.zone.today.iso8601
      assert_select ".post-pop__when select[name=hour][aria-label='Hour'][data-post-bar-target=hour][data-action~='post-bar#choose'] option", count: 24
      assert_select ".post-pop__when select[name=hour] option[selected][value=?]", Time.zone.now.hour.to_s
      assert_select "input[type=hidden][name=shown][data-post-bar-target=shown][value=?]", Time.zone.now.strftime("%Y-%m-%dT%H:00")
    end
    assert_select "[name='post[published_day]'], [name='post[published_hour]']", count: 0
  end

  test "edit shows the posts around the date beside the choices wherever one is picked, in the menu itself" do
    { posts(:draft) => %w[ day hour ], posts(:scheduled) => %w[ day hour ], posts(:unlisted) => %w[ post[published_day] post[published_hour] ] }.each do |post, (day, hour)|
      get edit_post_path(post)

      assert_select "dialog.post-pop > .post-pop__columns[data-controller=post-nearby][data-action='change->post-nearby#load']", count: 1 do
        assert_select ".post-pop__choices input[name=?][data-post-nearby-target=day]", day
        assert_select ".post-pop__choices select[name=?][data-post-nearby-target=hour]", hour

        assert_select ".post-pop__nearby" do
          assert_select ".post-pop__heading", text: "Posts around this date"
          assert_select "button, a", count: 0
          assert_select "turbo-frame#post-nearby[loading=lazy][data-post-nearby-target=frame][data-address=?]:not([src]):empty", post_nearby_path(post)
        end
      end
      assert_select "dialog dialog", count: 0
    end

    get edit_post_path(posts(:email_only))
    assert_select "turbo-frame#post-nearby, .post-pop__columns, .post-pop__nearby, dialog dialog", count: 0
  end

  test "edit gives the main button its word and its question for a past date" do
    past_confirm = "Publish this under a past date? It will not be mailed to your 1 subscriber."

    get edit_post_path(posts(:draft))

    assert_select "button.post-actions__primary span[data-post-bar-target=action]", text: "Publish and send to 1 subscriber"
    assert_select "input[name=destination][value=web_and_email][data-past-label='Publish'][data-past-confirm=?]", past_confirm
    assert_select "input[name=destination][value=email][data-past-label='Send to 1 subscriber']:not([data-past-confirm])"
    assert_select "input[name=destination][value=web][data-past-label='Publish']:not([data-past-confirm])"
    assert_select "input[name=destination][value=link][data-past-label='Publish by link']:not([data-past-confirm])"
  end

  test "edit gives the main button its word for a date ahead, which says who is mailed" do
    get edit_post_path(posts(:draft))

    assert_select "input[name=destination][value=web_and_email][data-schedule-label='Schedule and send to 1 subscriber']"
    assert_select "input[name=destination][value=email][data-schedule-label='Schedule and send to 1 subscriber']"
    assert_select "input[name=destination][value=web][data-schedule-label='Schedule']"
    assert_select "input[name=destination][value=link][data-schedule-label='Schedule']"
  end

  test "edit asks before the main button mails the list, and not before it only publishes" do
    confirm = "Mail this to 1 subscriber now? An email that has gone out cannot be changed or sent again."

    get edit_post_path(posts(:draft))
    assert_select "button.post-actions__primary[data-post-bar-target~=primary][data-turbo-confirm=?]", confirm, text: "Publish and send to 1 subscriber"
    assert_select "input[name=destination][value=email][data-confirm=?]", confirm

    get edit_post_path(posts(:unlisted))
    assert_select "button[data-turbo-confirm=?]", confirm, count: 0

    posts(:draft).update! visibility: "unlisted"
    get edit_post_path(posts(:draft))
    assert_select "button.post-actions__primary:not([data-turbo-confirm])", text: "Publish by link"
  end

  test "edit proposes what the draft's visibility says" do
    posts(:draft).update! visibility: "email_only"
    get edit_post_path(posts(:draft))
    assert_select "input[name=destination][value=email][checked]"
    assert_select "button.post-actions__primary", text: "Send to 1 subscriber"
    assert_select ".post-actions__state", text: /Email only/

    posts(:draft).update! visibility: "unlisted"
    get edit_post_path(posts(:draft))
    assert_select "input[name=destination][value=link][checked]"
    assert_select "button.post-actions__primary", text: "Publish by link"
  end

  test "edit offers a published post what its page may still change, in the main button's menu, and no sending" do
    get edit_post_path(posts(:unlisted))

    assert_select "dialog.post-pop", count: 1
    assert_select "input[name=destination]", count: 0
    assert_select "[name=day], [name=hour], [name=shown]", count: 0
    assert_select "dialog.post-pop--menu" do
      assert_select "button[type=button]", count: 0
      assert_select "button.post-pop__item[formaction='#{post_publication_path(posts(:unlisted))}'][name=_method][value=delete][data-turbo-confirm]", text: "Unpublish"
      assert_equal [ "Listed", "By link only", "Unpublish" ], css_select("dialog.post-pop--menu button[type=submit]").map { |button| button.text.strip }
    end
    assert_select ".writing-bar > button[formaction='#{post_publication_path(posts(:unlisted))}']", count: 0
  end

  test "edit offers an issue with no page one, in the main button's menu" do
    get edit_post_path(posts(:email_only))

    assert_select "button.post-actions__primary", text: "Save"
    assert_select "dialog.post-pop--menu" do
      assert_select "button.post-pop__item[formaction='#{post_publication_path(posts(:email_only))}'][name=_method][value=post]", text: "Publish on the web"
    end
  end

  test "edit opens a scheduled post's box on its schedule" do
    get edit_post_path(posts(:scheduled))

    assert_select "dialog.post-pop.post-pop--menu[aria-label='Change the schedule'][data-dialog-target=dialog][data-action='post-bar:submitted->dialog#close']", count: 1
    assert_select "dialog.post-pop--menu" do
      assert_select ".post-pop__heading", text: "Where it goes"
      assert_select ".post-pop__heading", text: "Publication date"
      assert_equal %w[ web_and_email email web link ], css_select("input[type=radio][name=destination]").map { |radio| radio["value"] }
      assert_select "input[type=radio][name=destination][checked]", count: 1
      assert_select "input[name=destination][value=web_and_email][checked][data-post-bar-target=destination][data-schedule-label='Schedule and send to 1 subscriber'][data-schedule-confirm='Schedule this to be mailed to 1 subscriber on the date picked?']"
      assert_select "input[name=destination][value=web][data-schedule-label='Schedule']:not([data-schedule-confirm])"
      assert_select "input[name=destination][value=web_and_email][data-past-label='Publish'][data-past-confirm]"
      assert_select "input[type=date][name=day]:not([min])[data-post-bar-target=day][value=?]", posts(:scheduled).scheduled_posting_at.to_date.iso8601
      assert_select "select[name=hour][data-post-bar-target=hour]"
      assert_select "select[name=hour] option[selected][value=?]", posts(:scheduled).scheduled_posting_at.hour.to_s
      assert_select ".post-pop__when:not([data-controller~=clicker])" do
        assert_select "[name=day][data-action='post-bar#choose keydown.enter->dialog#close:prevent'], [name=hour][data-action='post-bar#choose keydown.enter->dialog#close:prevent']", count: 2
      end
      assert_select "button[formaction='#{post_schedule_path(posts(:scheduled))}'][name=_method][value=post]", count: 0
    end
    assert_select "[name=day], [name=hour]", count: 2
    assert_select "[name=shown], button[formaction='#{post_release_path(posts(:scheduled))}']", count: 0
    assert_select "button.post-actions__primary[data-post-bar-target=primary][data-schedule-path='#{post_schedule_path(posts(:scheduled))}'] [data-post-bar-target=action]", text: "Schedule and send to 1 subscriber"
    assert_select "button.post-actions__primary[data-publication-path='#{post_publication_path(posts(:scheduled))}'][data-now=?]:not([data-release-path])", Time.zone.now.strftime("%Y-%m-%dT%H:00")
    assert_select ".post-actions__detail", text: /\AFor /

    posts(:scheduled).update! scheduled_delivery: false
    get edit_post_path(posts(:scheduled))
    assert_select "input[type=radio][name=destination][value=web][checked]"
    assert_select "button.post-actions__primary[formaction='#{post_schedule_path(posts(:scheduled))}']:not([data-turbo-confirm])", text: "Schedule"
  end

  test "edit without confirmed subscribers offers no sending" do
    subscribers(:active).deactivate

    get edit_post_path(posts(:draft))
    assert_equal %w[ web link ], css_select("input[type=radio][name=destination]").map { |radio| radio["value"] }
    assert_select "input[name=destination][value=web][checked]"
    assert_select "button.post-actions__primary:not([data-turbo-confirm])", text: "Publish"

    get edit_post_path(posts(:unlisted))
    assert_select "button.post-actions__primary", text: "Save"
  end

  test "edit without a complete sender still releases a draft, and says why it is not mailed" do
    account_senders(:davids).update!(from_address: nil)

    get edit_post_path(posts(:draft))
    assert_select "button.post-actions__primary", text: "Publish"
    assert_equal %w[ web link ], css_select("input[type=radio][name=destination]").map { |radio| radio["value"] }
    assert_select "input[name=destination][value=web][checked]"
    assert_select "dialog.post-pop--menu a", text: "Finish the settings"
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

  test "edit lets a published post on the web be listed or kept to its link at a press, outside the editor's form" do
    listing_form = ActionView::RecordIdentifier.dom_id(posts(:unlisted), :listing_form)

    get edit_post_path(posts(:unlisted))
    assert_select "form.writing__form form", count: 0
    assert_select ".writing[data-controller~='post-bar'] form##{listing_form}[action='#{post_listing_path(posts(:unlisted))}'][method=post][data-action='turbo:submit-end->post-bar#submitted']"
    assert_select "dialog.post-pop--menu [role=radiogroup]" do
      assert_select "button.post-pop__item[type=submit][form=#{listing_form}]:not([name])[role=radio][aria-checked=false]:not([disabled])", text: "Listed"
      assert_select "button.post-pop__item[type=submit][form=#{listing_form}][name=_method][value=delete][role=radio][aria-checked=true][disabled]", text: "By link only"
    end
    assert_select "input[name='post[visibility]']", count: 0

    get edit_post_path(posts(:sent))
    assert_select "dialog.post-pop--menu button[aria-checked=true][disabled]", text: "Listed"

    get edit_post_path(posts(:email_only))
    assert_select "button[role=radio]", count: 0
    assert_select "form[action='#{post_listing_path(posts(:email_only))}']", count: 0
  end

  test "edit keeps the test in a box of its own, opened from the bar beside the save, for a draft that can be mailed" do
    get edit_post_path(posts(:draft))
    assert_select "dialog.post-pop--menu .post-pop__test", count: 0
    assert_select ".writing-bar button.post-actions__beside[type=submit] ~ [data-controller=dialog] > button.post-actions__beside[type=button][aria-haspopup=dialog][data-action='dialog#toggle']", text: "Send a test"
    assert_select ".writing-bar [data-controller=dialog][data-action~='click@document->dialog#closeOnClickOutside'] > dialog.popup.post-pop:not(.post-pop--menu)[aria-label='Send a test'][data-dialog-target=dialog][data-action='post-bar:submitted->dialog#close'] > .post-pop__test[data-controller=clicker]" do
      assert_select "input[name=email_address][value='mia@example.com'][data-action='keydown.enter->clicker#click:prevent']"
      assert_select "button[formaction='#{post_test_delivery_path(posts(:draft))}'][name=_method][value=post][data-clicker-target=clickable]", text: "Send a test"
    end
    assert_select "input[name=email_address]", count: 1
    assert_select "dialog.post-pop", count: 2

    get edit_post_path(posts(:scheduled))
    assert_select ".writing-bar [data-controller=dialog] > button[type=button][data-action='dialog#toggle']", text: "Send a test"
    assert_select ".writing-bar dialog.post-pop[aria-label='Send a test'] > .post-pop__test[data-controller=clicker]" do
      assert_select "input[name=email_address]"
      assert_select "button[formaction='#{post_test_delivery_path(posts(:scheduled))}'][data-clicker-target=clickable]", text: "Send a test"
    end
    assert_select "dialog", count: 2

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

  test "show as JSON counts the readers who liked it and who did not" do
    posts(:sent).rate_by(subscribers(:active), "disliked")

    get post_path(posts(:sent), format: :json)

    assert_equal 0, response.parsed_body["liked_count"]
    assert_equal 1, response.parsed_body["disliked_count"]
  end

  test "show as JSON says the visibility and gives an email-only post no public address" do
    get post_path(posts(:email_only), format: :json)

    assert_equal "email_only", response.parsed_body["visibility"]
    assert_not response.parsed_body.key?("public_url")
  end

  test "edit shows a published post on the web its date, and no other post one" do
    get edit_post_path(posts(:unlisted))
    assert_select "input[type=date][name='post[published_day]'][value=?]", posts(:unlisted).published_at.to_date.iso8601
    assert_select "select[name='post[published_hour]'] option", count: 24
    assert_select "select[name='post[published_hour]'] option[selected][value=?]", posts(:unlisted).published_at.hour.to_s
    assert_select "[name='post[published_at]']", count: 0

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
    assert_select "input[name='post[published_day]'][value=?]", "2024-05-06"
  end

  test "update refuses a day left empty, and says why in the form" do
    assert_no_changes -> { posts(:unlisted).reload.published_at } do
      patch post_path(posts(:unlisted)), params: { post: { published_day: "", published_hour: "9" } }
    end

    assert_response :unprocessable_entity
    assert_select ".error-explanation", text: /cannot be left empty/
    assert_select "input[name='post[published_day]'][value=?]", posts(:unlisted).published_at.to_date.iso8601
  end

  test "update refuses a date still to come or left empty, and says why in the form" do
    assert_no_changes -> { posts(:unlisted).reload.published_at } do
      patch post_path(posts(:unlisted)), params: { post: { title: "Workshop notes", published_at: 1.day.from_now.strftime("%Y-%m-%dT%H:%M") } }
      assert_response :unprocessable_entity
      assert_select ".error-explanation", text: /cannot be in the future/

      patch post_path(posts(:unlisted)), params: { post: { published_at: "" } }
      assert_response :unprocessable_entity
      assert_select ".error-explanation", text: /cannot be left empty/
      assert_select "input[name='post[published_day]'][value=?]", posts(:unlisted).published_at.to_date.iso8601
      assert_select "input[name=auto_save]", count: 0
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

  test "update saves the summary, and the editor shows it" do
    patch post_path(posts(:draft)), params: { post: { summary: "On ladders" } }
    assert_equal "On ladders", posts(:draft).reload.summary

    get edit_post_path(posts(:draft))
    assert_select "textarea[name='post[summary]']", text: /On ladders/

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

  test "destroy deletes a mailed issue with its deliveries, links and ratings" do
    post = posts(:sent)
    post.rate_by(subscribers(:active), "liked")

    assert_difference -> { Post.count }, -1 do
      delete post_path(post)
    end

    assert_redirected_to posts_path
    assert_empty Post::Delivery.where(post_id: post.id)
    assert_empty Post::Link.where(post_id: post.id)
    assert_empty Post::Rating.where(post_id: post.id)
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
