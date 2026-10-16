require "test_helper"

class LocalesTest < ActiveSupport::TestCase
  LOCALES = %w[ en es ]

  # Rails looks these up itself and ships them in English, so Spanish may hold what our English file does not.
  RAILS_OWN = %w[ activemodel activerecord date datetime errors helpers number support time ]

  test "each language is one file, named for it" do
    assert_equal LOCALES.map { "#{it}.yml" }, Rails.root.glob("config/locales/*.yml").map { it.basename.to_s }.sort

    LOCALES.each do |locale|
      assert_equal [ locale ], YAML.load_file(file_for(locale)).keys, "#{locale}.yml holds another language"
    end
  end

  test "English and Spanish have the same keys" do
    assert_empty keys_in("en") - keys_in("es"), "Written in English and not in Spanish"
    assert_empty keys_in("es").reject { rails_own?(it) } - keys_in("en"), "Written in Spanish and not in English"
  end

  private
    def file_for(locale)
      Rails.root.join("config/locales/#{locale}.yml")
    end

    def keys_in(locale)
      flat_keys YAML.load_file(file_for(locale)).fetch(locale)
    end

    # "errors.messages.too_long.one": a counted string is compared form by form.
    def flat_keys(translations, prefix = nil)
      translations.flat_map do |key, value|
        path = [ prefix, key ].compact.join(".")
        value.is_a?(Hash) ? flat_keys(value, path) : path
      end
    end

    def rails_own?(key)
      RAILS_OWN.include?(key.split(".").first)
    end
end
