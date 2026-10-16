module Account::Localizable
  extend ActiveSupport::Concern

  LOCALES = %w[ en es ].freeze

  included do
    normalizes :locale, with: ->(value) { value.presence }

    validates :locale, inclusion: { in: LOCALES }, allow_nil: true
  end

  # A nil locale is the one nobody picked. It is named here, since `with_locale(nil)` keeps whatever
  # language the process was already in.
  def in_locale(&block)
    I18n.with_locale(locale || I18n.default_locale, &block)
  end
end
