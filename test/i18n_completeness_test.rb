require "test_helper"

# A general i18n safety net — caught a real bug where a YAML file had
# `settings:` defined twice, silently dropping the first definition.
# Scans app/ for literal t(...) calls and asserts each key resolves.
class I18nCompletenessTest < ActiveSupport::TestCase
  KEY_PATTERN = /\b(?:I18n\.)?t\(\s*"([a-zA-Z0-9_.]+)"/

  test "every literal translation key used in app/ exists in every locale" do
    # Rails-side t(...) calls use the full key path. app/javascript's t()
    # is scoped to the "js" subtree, so a bare t("copied") means
    # js.copied — keys from .js files need that prefix added back.
    ruby_and_erb_keys = Dir.glob(Rails.root.join("app/**/*.{rb,erb}")).flat_map do |path|
      File.read(path).scan(KEY_PATTERN).flatten
    end

    js_keys = Dir.glob(Rails.root.join("app/javascript/**/*.js")).flat_map do |path|
      File.read(path).scan(KEY_PATTERN).flatten
    end.map { |key| "js.#{key}" }

    keys = (ruby_and_erb_keys + js_keys).uniq

    assert_not_empty keys, "expected to find at least one t(...) call under app/ — did the scan pattern break?"

    missing = keys.flat_map do |key|
      I18n.available_locales.reject { |locale| I18n.exists?(key, locale) }.map { |locale| "#{key} (#{locale})" }
    end

    assert_empty missing, "missing translations:\n#{missing.join("\n")}"
  end

  # Duplicate top-level mapping keys are legal YAML — last one wins,
  # silently — so I18n.exists? alone can't catch a shadowed key. This
  # compares top-level key sets directly instead.
  test "no locale file defines the same top-level key twice" do
    Dir.glob(Rails.root.join("config/locales/*.yml")).each do |path|
      top_level_keys = File.readlines(path).grep(/\A  [a-zA-Z0-9_]+:\s*\z/).map(&:strip)
      duplicates = top_level_keys.tally.select { |_, count| count > 1 }.keys

      assert_empty duplicates, "#{path} defines the same top-level key more than once: #{duplicates.join(', ')}"
    end
  end
end
