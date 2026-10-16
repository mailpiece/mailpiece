class ApplicationMailer < ActionMailer::Base
  default from: Rails.env.local? ? ENV.fetch("MAILER_FROM_ADDRESS", "Mailpiece <mailpiece@example.com>") : ENV.fetch("MAILER_FROM_ADDRESS")

  layout "mailer"
  append_view_path Rails.root.join("app/views/mailers")

  private
    def default_url_options
      if Current.account
        super.merge(script_name: Current.account.slug)
      else
        super
      end
    end
end
