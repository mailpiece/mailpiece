require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "new ends with the footer, and offers help only where there is an address to write to" do
    untenanted { get new_session_path }

    assert_select "#footer", text: /Mailpiece/
    assert_select "#footer a[href^=mailto]", count: 0

    with_support_email_address "help@example.com" do
      untenanted { get new_session_path }

      assert_select "#footer a[href=?]", "mailto:help@example.com", text: "Send us an email"
    end
  end

  test "create sends magic link code when no account exists" do
    Account.destroy_all

    untenanted do
      post session_path, params: { email_address: "first-admin@example.com" }
    end

    assert_equal Identity.find_by!(email_address: "first-admin@example.com").magic_links.last.code, flash[:magic_link_code]
    assert_equal flash[:magic_link_code], response.headers["X-Magic-Link-Code"]
  end

  test "create does not send magic link code once account exists" do
    untenanted do
      post session_path, params: { email_address: "another-admin@example.com" }
    end

    assert_nil flash[:magic_link_code]
    assert_nil response.headers["X-Magic-Link-Code"]
  end

  test "destroy" do
    sign_in_as :leo

    untenanted do
      delete session_path

      assert_redirected_to new_session_path
      assert_not cookies[:session_token].present?
    end
  end

  test "destroy closes every remote connection for the signed-out identity and lets valid sessions reconnect" do
    leo = users(:leo)
    other_account_user = User.create!(identity: leo.identity, account: accounts(:other_account), role: "member", name: "Leo Elsewhere")

    sign_in_as :leo

    disconnected_users = []
    reconnect_flags = []
    remote_connections = Object.new
    remote_connections.define_singleton_method(:where) { |current_user:| disconnected_users << current_user; self }
    remote_connections.define_singleton_method(:disconnect) { |reconnect:| reconnect_flags << reconnect }
    ActionCable.server.stubs(:remote_connections).returns(remote_connections)

    untenanted do
      delete session_path
    end

    assert_equal [ leo, other_account_user ].map(&:id).sort, disconnected_users.map(&:id).sort,
      "sign-out must disconnect every per-account user of the signed-out identity"
    assert_equal [ true, true ], reconnect_flags,
      "reconnect must stay true so still-valid sessions on other devices recover"
  end

  test "destroy with an access token has no session to end and does not raise" do
    untenanted { delete session_path(format: :json), env: api_token_env }

    assert_response :no_content
  end
end
