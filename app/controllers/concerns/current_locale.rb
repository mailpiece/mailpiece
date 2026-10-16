# A newsletter is written in one language, so everything inside an account follows the account.
# Outside one there is only the browser to ask.
module CurrentLocale
  extend ActiveSupport::Concern

  included do
    around_action :set_current_locale

    helper_method :current_locale

    etag { current_locale }
  end

  private
    def set_current_locale(&)
      I18n.with_locale(current_locale, &)
    end

    def current_locale
      @current_locale ||= locale_from_account || locale_from_accepted_languages || I18n.default_locale
    end

    # An account that picked no language reads in the default one, whatever the browser asks for.
    def locale_from_account
      if Current.account
        Current.account.locale || I18n.default_locale
      end
    end

    def locale_from_accepted_languages
      accepted_languages.find { Account::Localizable::LOCALES.include?(it) }
    end

    # "es-AR,es;q=0.9,en;q=0.8" reads as es, es, en: the language of each range, the most wanted first.
    def accepted_languages
      accepted_language_ranges.sort_by.with_index { |(_, quality), index| [ -quality, index ] }.map(&:first)
    end

    def accepted_language_ranges
      request.headers["Accept-Language"].to_s.split(",").filter_map do |range|
        tag, quality = range.strip.split(/\s*;\s*q=/i)
        quality = quality ? quality.to_f : 1.0

        [ tag[/\A[a-z]+/i].to_s.downcase, quality ] if tag.present? && quality.positive?
      end
    end
end
