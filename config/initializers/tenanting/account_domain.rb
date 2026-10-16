module AccountDomain
  ENV_KEY = "mailpiece.account_domain"

  def self.request?(request)
    request.get_header(ENV_KEY).present?
  end

  def self.normalize(host)
    host.to_s.downcase.sub(/:\d+\z/, "").chomp(".").presence
  end

  class Extractor
    def initialize(app)
      @app = app
    end

    # A newsletter's own domain is that newsletter, whatever the path says: a number or a handle the earlier
    # extractors took from the path goes back into it, and the account they set is replaced.
    def call(env)
      if account = account_at_domain(env)
        request = ActionDispatch::Request.new(env)
        request.path_info = "#{request.script_name}#{request.path_info}"
        request.engine_script_name = request.script_name = ""

        env[ENV_KEY] = account.domain
        env["mailpiece.external_account_id"] = account.external_account_id
        Rails.event.set_context account_id: account.external_account_id

        Current.with_account(account) do
          @app.call env
        end
      else
        @app.call env
      end
    end

    private
      # HTTP_HOST and not request.host, which would take a forwarded host's word for it.
      def account_at_domain(env)
        if host = AccountDomain.normalize(env["HTTP_HOST"])
          Account.find_by(domain: host)
        end
      end
  end
end

# The last of the three: account_slug.rb and account_handle.rb load after this file and each inserts its own ahead.
Rails.application.config.middleware.insert_after Rack::TempfileReaper, AccountDomain::Extractor

# Active Storage's controllers take Authentication in lib/rails_ext and config/initializers/active_storage.rb,
# both prepared before this file, so the override lands after it there as it does in ApplicationController.
Rails.application.config.to_prepare do
  [ ActiveStorage::Blobs::RedirectController, ActiveStorage::Blobs::ProxyController,
    ActiveStorage::Representations::RedirectController, ActiveStorage::Representations::ProxyController,
    ActiveStorage::DirectUploadsController ].each do |controller|
    controller.include AccountDomainAuthentication
  end
end
