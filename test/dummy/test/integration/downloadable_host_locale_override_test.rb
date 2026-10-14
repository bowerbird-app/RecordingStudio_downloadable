# frozen_string_literal: true

require_relative "../test_helper"
require "devise/test/integration_helpers"

class DownloadableHostLocaleOverrideTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  HOST_TIMEOUT = "HOST Download is taking too long. Retry."
  HOST_DOWNLOAD = "HOST Download"
  TIMEOUT_KEY = "recording_studio.downloadable.notices.timeout"
  DOWNLOAD_KEY = "recording_studio.downloadable.buttons.download"
  BOOT_HOST_LOCALE = Rails.root.join("config/locales/recording_studio_downloadable_host.en.yml")
  FRESH_HOST_LOCALE = Rails.root.join("test/locales/downloadable_host_override.en.yml")

  setup do
    @load_path_before = I18n.load_path.dup
    @backend_before = I18n.backend
    @user = User.find_or_create_by!(email: "host-override@example.com") do |record|
      record.password = "Password"
      record.password_confirmation = "Password"
    end
    @workspace = Workspace.find_or_create_by!(name: "Studio Workspace")
    @recording = RecordingStudio.root_recording_for(@workspace)
    grant_studio_download_access!(@recording, @user)
    Current.actor = @user if defined?(Current)
  end

  teardown do
    I18n.backend = @backend_before if @backend_before
    Current.actor = nil if defined?(Current)
    assert_equal @load_path_before, I18n.load_path,
                 "test must not leave I18n.load_path modified"
  end

  # Real-boot-order guard: host file under config/locales must win without any
  # test-time load_path mutation. Timeout copy is only shown after poll failure;
  # the Stimulus data attribute still renders it on pages with a Download control.
  test "host locale override for recording_studio.downloadable wins on boot order" do
    assert File.exist?(BOOT_HOST_LOCALE)
    assert_includes File.read(BOOT_HOST_LOCALE), HOST_TIMEOUT
    assert_equal HOST_TIMEOUT, I18n.t(TIMEOUT_KEY)
    assert_equal @load_path_before, I18n.load_path,
                 "boot-order test must not mutate I18n.load_path"

    sign_in @user
    get "/"

    assert_response :success
    assert_includes response.body, HOST_TIMEOUT
    assert_includes response.body, "Download"
    refute_includes response.body, 'package-ready-text-value="HOST Download"'
  end

  # Test-only fixture applied via backend.load_translations(file) on top of the
  # already-initialized backend — never mutates I18n.load_path (Marshal).
  test "fresh-backend last-file-wins host fixture overrides gem english on download button" do
    assert File.exist?(FRESH_HOST_LOCALE), "expected test-only host override fixture at #{FRESH_HOST_LOCALE}"
    assert_includes File.read(FRESH_HOST_LOCALE), HOST_DOWNLOAD

    sign_in @user

    snapshot = i18n_backend_translations_snapshot
    I18n.t(DOWNLOAD_KEY)
    I18n.backend.load_translations(FRESH_HOST_LOCALE.to_s)

    assert_equal @load_path_before, I18n.load_path
    assert_equal HOST_DOWNLOAD, I18n.t(DOWNLOAD_KEY)
    assert_equal HOST_TIMEOUT, I18n.t(TIMEOUT_KEY)

    get "/"
    assert_response :success
    assert_includes response.body, HOST_DOWNLOAD
    assert_includes response.body, HOST_TIMEOUT
  ensure
    restore_i18n_backend_translations(snapshot) if snapshot
  end

  private

  def i18n_backend_translations_snapshot
    backend = I18n.backend
    backend.send(:init_translations) unless backend.initialized?
    translations =
      if backend.respond_to?(:translations)
        backend.translations
      else
        backend.instance_variable_get(:@translations)
      end
    return unless translations

    deep_plain_copy(translations)
  end

  def restore_i18n_backend_translations(snapshot)
    backend = I18n.backend
    backend.instance_variable_set(:@translations, snapshot)
    backend.instance_variable_set(:@initialized, true) if backend.instance_variable_defined?(:@initialized)
  end

  def deep_plain_copy(value)
    case value
    when Hash
      value.each_with_object({}) { |(key, child), result| result[key] = deep_plain_copy(child) }
    when Array
      value.map { |child| deep_plain_copy(child) }
    else
      value
    end
  end
end
