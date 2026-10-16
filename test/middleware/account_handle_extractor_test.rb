require "test_helper"
require "rack/mock"

class AccountHandleExtractorTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:davids_account)
    @account.update!(handle: "contractor-notes")
  end

  test "runs right after the account slug extractor" do
    middlewares = Rails.application.middleware.map(&:klass)

    assert_equal middlewares.index(AccountSlug::Extractor) + 1, middlewares.index(AccountHandle::Extractor)
  end

  test "an account answers at its handle as well as its number" do
    captured = call_with_env "/contractor-notes/landing"

    assert_equal "/contractor-notes", captured.fetch(:script_name)
    assert_equal "/landing", captured.fetch(:path_info)
    assert_equal @account.external_account_id, captured.fetch(:external_account_id)
    assert_equal @account, captured.fetch(:current_account)
    assert_equal @account, call_with_env("/#{@account.external_account_id}/landing").fetch(:current_account)
    assert_equal "/", call_with_env("/contractor-notes").fetch(:path_info)
  end

  test "a path that starts with digits is left alone after a handle" do
    captured = call_with_env "/contractor-notes/2024-in-review-1a2b3c4d"

    assert_equal "/contractor-notes", captured.fetch(:script_name)
    assert_equal "/2024-in-review-1a2b3c4d", captured.fetch(:path_info)
    assert_equal @account, captured.fetch(:current_account)
  end

  test "detects the handle when already in SCRIPT_NAME" do
    captured = call_with_env "/landing", "SCRIPT_NAME" => "/contractor-notes"

    assert_equal "/contractor-notes", captured.fetch(:script_name)
    assert_equal "/landing", captured.fetch(:path_info)
    assert_equal @account.external_account_id, captured.fetch(:external_account_id)
    assert_equal @account, captured.fetch(:current_account)
  end

  test "a number no account has is still an account's place, with nobody there" do
    captured = call_with_env "/999/landing"

    assert_equal "/999", captured.fetch(:script_name)
    assert_equal "/landing", captured.fetch(:path_info)
    assert_nil captured.fetch(:current_account)
  end

  test "a word no account answers to is left in the path" do
    captured = call_with_env "/session/new"

    assert_equal "", captured.fetch(:script_name)
    assert_equal "/session/new", captured.fetch(:path_info)
    assert_nil captured.fetch(:external_account_id)
    assert_nil captured.fetch(:current_account)
  end

  test "a word that only begins with a handle is left in the path" do
    captured = call_with_env "/contractor-notes-2/landing"

    assert_equal "", captured.fetch(:script_name)
    assert_equal "/contractor-notes-2/landing", captured.fetch(:path_info)
    assert_nil captured.fetch(:current_account)
  end

  private
    def call_with_env(path, extra_env = {})
      captured = {}
      extra_env = { "action_dispatch.routes" => Rails.application.routes }.merge(extra_env)

      app = ->(env) do
        captured[:script_name] = env["SCRIPT_NAME"]
        captured[:path_info] = env["PATH_INFO"]
        captured[:external_account_id] = env["mailpiece.external_account_id"]
        captured[:current_account] = Current.account
        [ 200, {}, [ "ok" ] ]
      end

      middleware = AccountSlug::Extractor.new(AccountHandle::Extractor.new(app))
      middleware.call Rack::MockRequest.env_for(path, extra_env.merge(method: "GET"))

      captured
    end
end
