require_relative "boot"

require "rails/all"
require_relative "../lib/action_pack/railtie"

Bundler.require(*Rails.groups)

module Mailpiece
  class Application < Rails::Application
    config.load_defaults 8.1

    # Set here rather than in an initializer: Active Record copies these into filter_attributes when it
    # loads, and an initializer can load it before a later one runs.
    config.filter_parameters += %i[
      passw passkey secret token _key crypt salt certificate otp ssn email
      subject text html attachments headers
      rcpt_to mail_from payload
    ]

    config.autoload_lib ignore: %w[ assets tasks rails_ext puma ]

    config.i18n.available_locales = [ :en, :es ]
    config.i18n.default_locale = :en
    config.i18n.fallbacks = [ :en ]

    # Rails 8.1 disabled event debug_mode by default; keep SQL query logs.
    # https://github.com/rails/rails/pull/55900
    config.after_initialize do
      Rails.event.debug_mode = true
    end

    config.generators do |g|
      g.orm :active_record, primary_key_type: :uuid
    end

    config.action_pack.passkey.draw_routes = false
    config.action_pack.passkey.challenge_url = -> { my_passkey_challenge_path(script_name: "") }

    config.mission_control.jobs.http_basic_auth_enabled = false

    initializer "mailpiece.trusted_proxies", after: :setup_main_autoloader, before: :build_middleware_stack do |app|
      Rack::Request.forwarded_priority = [ :x_forwarded ]

      trusted_proxies = ENV.fetch("TRUSTED_PROXIES", "").split(",").map(&:strip).compact_blank.map { |proxy| IPAddr.new(proxy) }

      app.config.action_dispatch.trusted_proxies =
        ActionDispatch::RemoteIp::TRUSTED_PROXIES + trusted_proxies
    end
  end
end
