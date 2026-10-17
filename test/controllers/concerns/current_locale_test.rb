require "test_helper"

class CurrentLocaleTest < ActionDispatch::IntegrationTest
  test "the most wanted language we have wins" do
    assert_language "es", "es-AR,es;q=0.9,en;q=0.8"
  end

  test "quality beats order" do
    assert_language "es", "en;q=0.8, es;q=0.9"
  end

  test "a language we lack falls back to the default" do
    assert_language "en", "fr"
  end

  test "q may be uppercase" do
    assert_language "es", "es;Q=0.9"
  end

  test "spaces around the semicolon are allowed" do
    assert_language "es", "es ; q=0.9"
  end

  test "a range of many spaces is read quickly" do
    assert_language "es", "#{' ' * 10_000},es"
  end

  private
    def assert_language(language, header)
      untenanted { get new_session_path, headers: { "Accept-Language" => header } }

      assert_select "html[lang=?]", language
    end
end
