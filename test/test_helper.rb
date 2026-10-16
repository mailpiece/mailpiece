ENV["RAILS_ENV"] ||= "test"

# No test sends through the mail settings of whoever runs it. Parallel workers fork from this process, so they inherit it.
ENV.delete_if { |name, _| name.start_with?("NEWSLETTER_MAIL_") }

require_relative "../config/environment"
require "rails/test_help"
require "webmock/minitest"
require "mocha/minitest"

unless [ "0", "false" ].include?(ENV["CI_PROGRESS_BAR"])
  require "minitest/reporters"
  Minitest::Reporters.use! Minitest::Reporters::ProgressReporter.new(detailed_skip: false)
end

module ActiveSupport
  class TestCase
    parallelize workers: :number_of_processors, work_stealing: ENV["WORK_STEALING"] != "false"

    fixtures :all

    include ActiveJob::TestHelper
    include MailTransportTestHelper
    include SupportTestHelper

    setup do
      Current.account = accounts(:davids_account)
      Current.user = users(:leo)
    end

    teardown do
      Current.clear_all
    end
  end
end

module ActionDispatch
  class IntegrationTest
    include SessionTestHelper

    setup do
      integration_session.default_url_options = integration_session.default_url_options.merge(script_name: "/#{accounts(:davids_account).external_account_id}")
    end

    def bearer_token_env(token)
      { "HTTP_AUTHORIZATION" => "Bearer #{token}" }
    end

    def api_token_env
      bearer_token_env("test_token_davids_api_0000000000")
    end

    def readonly_api_token_env
      bearer_token_env("test_token_davids_readonly_00000")
    end
  end
end

ActiveSupport.on_load(:active_record_fixture_set) do
  prepend(FixtureUuidTestHelper)
end
