require "test_helper"

class HostsControllerTest < ActionDispatch::IntegrationTest
  DOMAIN = "boletin.example"

  setup do
    accounts(:davids_account).update!(domain: DOMAIN)
  end

  test "the app's own host is answered" do
    ask "example.com"

    assert_response :ok
    assert_empty response.body
  end

  test "a newsletter's domain is answered, asked on that domain" do
    ask DOMAIN

    assert_response :ok
    assert_empty response.body
  end

  test "an unknown host is refused" do
    ask "unknown.example"

    assert_response :not_found
    assert_empty response.body
  end

  test "a domain no longer a newsletter's is refused" do
    accounts(:davids_account).update!(domain: nil)

    ask DOMAIN

    assert_response :not_found
  end

  test "no host is refused" do
    get "/up/host"
    assert_response :not_found

    get "/up/host", params: { host: "" }
    assert_response :not_found
  end

  test "a host is read whatever its case, port or trailing dot" do
    ask "Boletin.Example:443"
    assert_response :ok

    ask "#{DOMAIN}."
    assert_response :ok

    ask "EXAMPLE.com:80"
    assert_response :ok
  end

  test "the answer is the same on any host and under an account's address" do
    [ "example.com", DOMAIN, "unknown.example" ].each do |host|
      host! host

      get "/up/host", params: { host: DOMAIN }
      assert_response :ok, "asked on #{host}"

      get "/up/host", params: { host: "unknown.example" }
      assert_response :not_found, "asked on #{host}"
    end

    host! "example.com"
    get "/#{accounts(:davids_account).external_account_id}/up/host", params: { host: DOMAIN }
    assert_response :ok
  end

  test "it answers with no session and sets no cookie" do
    ask DOMAIN

    assert_response :ok
    assert_nil response.headers["Set-Cookie"]
  end

  private
    # As the proxy asks: the hostname in the query and in the Host header, and no account in the path.
    def ask(host)
      host! host
      get "/up/host", params: { host: host }
    end
end
