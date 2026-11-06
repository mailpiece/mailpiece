require "test_helper"

# A next-page link is built from the request's query string, so what a query says
# must only ever end up back in a query string. These tests render every page that
# paginates with url_for, through real routing, because url_for reads its recalled
# route from the request and a helper test can't vouch for that.
class PaginationLinksTest < ActionDispatch::IntegrationTest
  QUERIES_NAMING_URL_FOR_OPTIONS = [
    { use_route: "root" },
    { use_route: "subscriber", id: "1" },
    { path_params: { format: "xml" } }
  ]

  setup do
    @account = accounts(:davids_account)
  end

  test "public posts page's next-page link stays on its own route" do
    paginate :posts

    assert_next_page_stays_on root_path
    QUERIES_NAMING_URL_FOR_OPTIONS.each { |query| assert_next_page_stays_on root_path, **query }
  end

  { "published" => :posts_published_path, "sent" => :posts_sent_path }.each do |name, page|
    test "#{name} posts page's next-page link stays on its own route" do
      paginate :posts
      sign_in_as :leo

      assert_next_page_stays_on public_send(page)
      QUERIES_NAMING_URL_FOR_OPTIONS.each { |query| assert_next_page_stays_on public_send(page), **query }
    end
  end

  { "active" => [ :active, :subscribers_active_path ],
    "unconfirmed" => [ :unconfirmed, :subscribers_unconfirmed_path ], "unsubscribed" => [ :unsubscribed, :subscribers_unsubscribed_path ],
    "bounced" => [ :bounced, :subscribers_bounced_path ], "deactivated" => [ :deactivated, :subscribers_deactivated_path ] }.each do |name, (status, page)|
    test "#{name} page's next-page link stays on its own route" do
      paginate status
      sign_in_as :leo

      assert_next_page_stays_on public_send(page)
      QUERIES_NAMING_URL_FOR_OPTIONS.each { |query| assert_next_page_stays_on public_send(page), **query }
    end
  end

  test "snippets page's next-page link stays on its own route" do
    paginate :snippets
    sign_in_as :leo

    assert_next_page_stays_on snippets_path
    QUERIES_NAMING_URL_FOR_OPTIONS.each { |query| assert_next_page_stays_on snippets_path, **query }
  end

  test "search page's next-page link stays on its own route and keeps the search" do
    paginate :active, email: "needle"
    sign_in_as :leo

    [ {}, *QUERIES_NAMING_URL_FOR_OPTIONS ].each do |query|
      assert_next_page_stays_on search_path, q: "needle", **query
      assert_equal "needle", next_page_query["q"]
    end
  end

  test "the next-page link answers with the next page" do
    paginate :posts

    get root_path, params: { use_route: "root" }
    get next_page_href

    assert_response :success
    assert_select "a.pagination-link", count: 0
  end

  private
    def paginate(kind, email: "paginated")
      16.times do |index|
        case kind
        when :posts then @account.posts.create!(title: "Paginated #{index}", creator: users(:leo), published_at: Time.current, sent_at: Time.current)
        when :snippets then @account.snippets.create!(name: "Paginated #{index}")
        when :active then @account.subscribers.create!(email: "#{email}#{index}@example.org", confirmed_at: 1.day.ago)
        when :unconfirmed then @account.subscribers.create!(email: "#{email}#{index}@example.org")
        when :unsubscribed then @account.subscribers.create!(email: "#{email}#{index}@example.org", unsubscribed_at: 1.day.ago)
        when :bounced then @account.subscribers.create!(email: "#{email}#{index}@example.org", bounced_at: 1.day.ago)
        when :deactivated then @account.subscribers.create!(email: "#{email}#{index}@example.org", deactivated_at: 1.day.ago)
        end
      end
    end

    def assert_next_page_stays_on(path, **query)
      get path, params: query
      assert_response :success

      assert_equal path, URI(next_page_href).path
      assert_equal "2", next_page_query["page"]
    end

    def next_page_href
      css_select("a.pagination-link").first&.[]("href") || flunk("expected a next-page link")
    end

    def next_page_query
      Rack::Utils.parse_nested_query(URI(next_page_href).query)
    end
end
