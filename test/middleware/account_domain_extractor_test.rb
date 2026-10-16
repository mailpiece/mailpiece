require "test_helper"
require "rack/mock"

class AccountDomainExtractorTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:davids_account)
    @account.update!(domain: "boletin.example")
    @other = accounts(:other_account)
    @other.update!(handle: "other-notes")
  end

  test "runs last of the three extractors" do
    middlewares = Rails.application.middleware.map(&:klass)
    slug = middlewares.index(AccountSlug::Extractor)

    assert_equal [ AccountSlug::Extractor, AccountHandle::Extractor, AccountDomain::Extractor ], middlewares[slug, 3]
  end

  test "a newsletter answers at the root of its domain" do
    captured = call_with_env "/feed", "HTTP_HOST" => "boletin.example"

    assert_equal "", captured.fetch(:script_name)
    assert_equal "/feed", captured.fetch(:path_info)
    assert_equal @account.external_account_id, captured.fetch(:external_account_id)
    assert_equal @account, captured.fetch(:current_account)
    assert captured.fetch(:account_domain)
  end

  test "the host is read whatever its case, port or trailing dot" do
    [ "Boletin.Example", "boletin.example:3020", "boletin.example.", "BOLETIN.example.:443" ].each do |host|
      captured = call_with_env "/", "HTTP_HOST" => host

      assert_equal @account, captured.fetch(:current_account), "#{host} should be the newsletter's"
      assert captured.fetch(:account_domain)
    end
  end

  test "another newsletter's handle is an ordinary path on a domain" do
    captured = call_with_env "/other-notes/feed", "HTTP_HOST" => "boletin.example"

    assert_equal "", captured.fetch(:script_name)
    assert_equal "/other-notes/feed", captured.fetch(:path_info)
    assert_equal @account.external_account_id, captured.fetch(:external_account_id)
    assert_equal @account, captured.fetch(:current_account)
  end

  test "a number is an ordinary path on a domain, another newsletter's or its own" do
    [ @other, @account ].each do |account|
      captured = call_with_env "/#{account.external_account_id}/feed", "HTTP_HOST" => "boletin.example"

      assert_equal "", captured.fetch(:script_name)
      assert_equal "/#{account.external_account_id}/feed", captured.fetch(:path_info)
      assert_equal @account.external_account_id, captured.fetch(:external_account_id)
      assert_equal @account, captured.fetch(:current_account)
    end
  end

  test "a post whose title starts with digits keeps its path on a domain" do
    captured = call_with_env "/2024-in-review-1a2b3c4d", "HTTP_HOST" => "boletin.example"

    assert_equal "", captured.fetch(:script_name)
    assert_equal "/2024-in-review-1a2b3c4d", captured.fetch(:path_info)
    assert_equal @account, captured.fetch(:current_account)
  end

  test "a host that is no newsletter's is left to the path" do
    captured = call_with_env "/other-notes/feed", "HTTP_HOST" => "www.example.com"

    assert_equal "/other-notes", captured.fetch(:script_name)
    assert_equal "/feed", captured.fetch(:path_info)
    assert_equal @other, captured.fetch(:current_account)
    assert_nil captured.fetch(:account_domain)

    captured = call_with_env "/session/new", "HTTP_HOST" => "www.example.com"

    assert_equal "/session/new", captured.fetch(:path_info)
    assert_nil captured.fetch(:current_account)
    assert_nil captured.fetch(:account_domain)
  end

  test "a forwarded host is not taken for the newsletter's domain" do
    captured = call_with_env "/feed", "HTTP_HOST" => "www.example.com", "HTTP_X_FORWARDED_HOST" => "boletin.example"

    assert_equal "/feed", captured.fetch(:path_info)
    assert_nil captured.fetch(:external_account_id)
    assert_nil captured.fetch(:current_account)
    assert_nil captured.fetch(:account_domain)

    captured = call_with_env "/feed", "HTTP_HOST" => "boletin.example", "HTTP_X_FORWARDED_HOST" => "www.example.com"

    assert_equal @account, captured.fetch(:current_account)
    assert captured.fetch(:account_domain)
  end

  private
    def call_with_env(path, extra_env = {})
      captured = {}
      extra_env = { "action_dispatch.routes" => Rails.application.routes }.merge(extra_env)

      app = ->(env) do
        captured[:script_name] = env["SCRIPT_NAME"]
        captured[:path_info] = env["PATH_INFO"]
        captured[:external_account_id] = env["mailpiece.external_account_id"]
        captured[:account_domain] = env["mailpiece.account_domain"]
        captured[:current_account] = Current.account
        [ 200, {}, [ "ok" ] ]
      end

      middleware = AccountSlug::Extractor.new(AccountHandle::Extractor.new(AccountDomain::Extractor.new(app)))
      middleware.call Rack::MockRequest.env_for(path, extra_env.merge(method: "GET"))

      captured
    end
end
