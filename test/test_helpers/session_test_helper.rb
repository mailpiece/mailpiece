module SessionTestHelper
  def sign_in_as(user_or_fixture)
    user = user_or_fixture.is_a?(User) ? user_or_fixture : users(user_or_fixture)
    identity = user.identity

    identity.send_magic_link
    magic_link = identity.magic_links.order(id: :desc).first

    tenanted_options = default_url_options
    reset!
    self.default_url_options = tenanted_options

    untenanted do
      post session_path, params: { email_address: identity.email_address }
      post session_magic_link_url, params: { code: magic_link.code }
    end
  end

  def untenanted
    original_options = integration_session.default_url_options
    integration_session.default_url_options = original_options.merge(script_name: "")
    yield
  ensure
    integration_session.default_url_options = original_options
  end

  def with_multi_tenant_mode(enabled)
    previous = Account.multi_tenant
    Account.multi_tenant = enabled
    yield
  ensure
    Account.multi_tenant = previous
  end
end
