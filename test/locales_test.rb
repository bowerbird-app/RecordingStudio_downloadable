# frozen_string_literal: true

require_relative "downloadable_test_helper"
require "yaml"

class LocalesTest < ActiveSupport::TestCase
  Copy = RecordingStudioDownloadable::Copy

  EXPECTED = {
    "buttons.download" => Copy::DOWNLOAD_BUTTON,
    "buttons.preparing" => Copy::PREPARING_BUTTON,
    "buttons.retry" => Copy::RETRY_BUTTON,
    "notices.empty" => Copy::EMPTY_NOTICE,
    "notices.ready" => Copy::READY_NOTICE,
    "notices.building" => Copy::BUILDING_NOTICE,
    "notices.not_ready" => Copy::NOT_READY_NOTICE,
    "notices.timeout" => Copy::TIMEOUT_NOTICE,
    "errors.not_authorized" => Copy::NOT_AUTHORIZED,
    "errors.capability_disabled" => Copy::CAPABILITY_DISABLED,
    "errors.rate_limited" => Copy::RATE_LIMITED,
    "errors.concurrent_builds" => Copy::CONCURRENT_BUILDS,
    "errors.archive_too_large" => Copy::ARCHIVE_TOO_LARGE,
    "errors.not_ready" => Copy::NOT_READY_NOTICE
  }.freeze

  def setup
    @previous_load_path = I18n.load_path.dup
    @previous_backend = I18n.backend
    @previous_locale = I18n.locale
    I18n.backend = I18n::Backend::Simple.new
    I18n.backend.load_translations(*Dir[File.join(engine_locales_dir, "*.yml")])
    # load_translations alone leaves initialized=false; the next I18n.t would
    # re-init from the full load_path (including the dummy boot-order host file).
    I18n.backend.instance_variable_set(:@initialized, true)
    I18n.locale = :en
  end

  def teardown
    I18n.backend = @previous_backend
    I18n.locale = @previous_locale
    assert_equal @previous_load_path, I18n.load_path,
                 "locales tests must not mutate I18n.load_path"
  end

  test "engine ships only english locale files" do
    files = Dir[File.join(engine_locales_dir, "*")].map { |path| File.basename(path) }

    assert_equal ["en.yml"], files.sort
  end

  test "rails i18n load path includes the gem english locale file" do
    locale_path = File.expand_path(File.join(engine_locales_dir, "en.yml"))
    existent = RecordingStudioDownloadable::Engine.paths["config/locales"].existent.map do |path|
      File.expand_path(path)
    end

    assert_includes existent, locale_path
  end

  test "lib sources do not append i18n load path" do
    lib_root = File.expand_path("../lib", __dir__)
    ruby_files = Dir[File.join(lib_root, "**", "*.rb")]

    refute_empty ruby_files, "expected lib/**/*.rb files to scan"

    ruby_files.each do |path|
      source = File.read(path)

      refute_includes source, "i18n.load_path", "#{path} must not touch i18n.load_path"
      refute_includes source, "I18n.load_path", "#{path} must not touch I18n.load_path"
    end
  end

  test "english downloadable keys resolve without missing translations" do
    I18n.with_locale(:en) do
      EXPECTED.each do |key, english|
        assert_equal english, I18n.t("recording_studio.downloadable.#{key}", raise: true),
                     "expected #{key} to resolve to #{english.inspect}"
        assert_equal english, Copy.t(key, default: english),
                     "expected Copy.t(#{key.inspect}) to resolve to #{english.inspect}"
      end
    end
  end

  test "en.yml nests keys under recording_studio.downloadable" do
    tree = locale_tree(File.join(engine_locales_dir, "en.yml"), "en")
           .fetch("recording_studio")
           .fetch("downloadable")

    refute locale_tree(File.join(engine_locales_dir, "en.yml"), "en").key?("recording_studio_downloadable")

    EXPECTED.each do |key, english|
      parts = key.split(".")
      value = parts.reduce(tree) { |memo, part| memo.fetch(part) }
      assert_equal english, value
    end
  end

  test "copy t default english wins when key missing in locale" do
    I18n.with_locale(:en) do
      assert_equal(
        Copy::EMPTY_NOTICE,
        Copy.t("notices.empty", default: Copy::EMPTY_NOTICE)
      )
      assert_equal(
        "Fallback label",
        Copy.t("notices.missing_wave2_key", default: "Fallback label")
      )
    end
  end

  test "quoted yes no on off keys resolve when present" do
    keys = collect_yes_no_on_off_keys(
      locale_tree(File.join(engine_locales_dir, "en.yml"), "en")
        .fetch("recording_studio")
        .fetch("downloadable")
    )

    keys.each do |key|
      assert_equal(
        I18n.t("recording_studio.downloadable.#{key}", raise: true),
        Copy.t(key),
        "yes/no/on/off key #{key} must resolve without default:"
      )
    end
  end

  test "failure message mapper is pass-through-safe for unknown strings" do
    I18n.with_locale(:en) do
      assert_equal Copy::EMPTY_NOTICE, Copy.failure_message(Copy::EMPTY_NOTICE)
      assert_equal Copy::ARCHIVE_TOO_LARGE, Copy.failure_message(Copy::ARCHIVE_TOO_LARGE)
      assert_equal "Source set is empty", Copy.failure_message("Source set is empty")
      assert_nil Copy.failure_message(nil)
      assert_equal "", Copy.failure_message("")
      assert_equal "Déjà traduit", Copy.failure_message("Déjà traduit")
    end
  end

  test "raise and persist copy t stays locale-aware with english default" do
    with_french_downloadable_translations do
      I18n.with_locale(:fr) do
        assert_equal "Non autorisé à télécharger ce paquet",
                     Copy.t("errors.not_authorized", default: Copy::NOT_AUTHORIZED)
        assert_equal "Trop de demandes de téléchargement.",
                     Copy.t("errors.rate_limited", default: Copy::RATE_LIMITED)
        assert_equal "Rien à empaqueter.",
                     Copy.t("notices.empty", default: Copy::EMPTY_NOTICE)
      end

      I18n.with_locale(:en) do
        assert_equal Copy::NOT_AUTHORIZED,
                     Copy.t("errors.not_authorized", default: Copy::NOT_AUTHORIZED)
        assert_equal Copy::EMPTY_NOTICE,
                     Copy.t("notices.empty", default: Copy::EMPTY_NOTICE)
      end
    end
  end

  test "raised and persisted english defaults stay on copy constants" do
    assert_equal "Nothing to package.", Copy::EMPTY_NOTICE
    assert_equal "Not authorized to download this package", Copy::NOT_AUTHORIZED
    assert_equal "Downloads are not enabled for this item", Copy::CAPABILITY_DISABLED
    assert_equal "Too many download requests. Try again shortly.", Copy::RATE_LIMITED
    assert_equal "A download is already being built. Try again shortly.", Copy::CONCURRENT_BUILDS
    assert_equal "This download is too large to package.", Copy::ARCHIVE_TOO_LARGE
  end

  private

  def engine_locales_dir
    File.expand_path("../config/locales", __dir__)
  end

  def locale_tree(path, locale)
    YAML.safe_load_file(path, aliases: true).fetch(locale)
  end

  def collect_yes_no_on_off_keys(hash, prefix = [])
    hash.flat_map do |key, value|
      path = prefix + [key.to_s]
      if value.is_a?(Hash)
        collect_yes_no_on_off_keys(value, path)
      elsif %w[yes no on off true false null].include?(key.to_s)
        [path.join(".")]
      else
        []
      end
    end
  end

  def with_french_downloadable_translations
    previous_locales = I18n.available_locales
    I18n.available_locales = Array(previous_locales) | [:fr]
    I18n.backend.store_translations(
      :fr,
      recording_studio: {
        downloadable: {
          errors: {
            not_authorized: "Non autorisé à télécharger ce paquet",
            rate_limited: "Trop de demandes de téléchargement.",
            archive_too_large: "Ce téléchargement est trop volumineux."
          },
          notices: { empty: "Rien à empaqueter." }
        }
      }
    )
    yield
  ensure
    I18n.available_locales = previous_locales if previous_locales
  end
end
