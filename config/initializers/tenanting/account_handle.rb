module AccountHandle
  PATH_INFO_MATCH = /\A(\/([a-z][a-z0-9-]*))(?=\/|\z)/

  class Extractor
    def initialize(app)
      @app = app
    end

    # An account also answers at its handle. A word no account answers to is an ordinary path.
    def call(env)
      request = ActionDispatch::Request.new(env)
      Rails.event.set_context request_id: request.request_id

      if env["mailpiece.external_account_id"]
        Rails.event.set_context account_id: Current.account&.external_account_id
        @app.call env
      elsif account = account_at_handle(request)
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
      def account_at_handle(request)
        if request.script_name =~ PATH_INFO_MATCH
          # Action Cable reconnect after upgrade can leave the handle on script_name.
          Account.find_by(handle: $2)
        elsif request.path_info =~ PATH_INFO_MATCH
          prefix, rest = $1, $'

          Account.find_by(handle: $2)&.tap do
            request.engine_script_name = request.script_name = prefix
            request.path_info = rest.empty? ? "/" : rest
          end
        end
      end
  end
end

# Runs after AccountSlug::Extractor, whose pattern takes any leading digits for an account: /handle/2024-in-review
# stripped first would be misread. This file loads before account_slug.rb, which then inserts its own in between.
Rails.application.config.middleware.insert_after Rack::TempfileReaper, AccountHandle::Extractor
