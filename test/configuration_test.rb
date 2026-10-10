# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  def setup
    @configuration = RecordingStudioDownloadable::Configuration.new
  end

  def test_merge_updates_known_attributes
    adapter = ->(**) { true }
    @configuration.merge!(auth_roles: { download: :admin }, authorize_with: adapter)

    assert_equal({ download: :admin }, @configuration.auth_roles)
    assert_equal adapter, @configuration.authorize_with
  end

  def test_merge_ignores_unknown_keys
    @configuration.merge!(unknown_key: "ignored", auth_roles: { download: :edit })

    refute_respond_to @configuration, :unknown_key
    assert_equal({ download: :edit }, @configuration.auth_roles)
  end

  def test_merge_with_non_enumerable_is_noop
    original = @configuration.to_h

    @configuration.merge!(nil)

    assert_equal original[:auth_roles], @configuration.auth_roles
  end

  def test_defaults_map_download_to_view
    assert_equal({ download: :view }, @configuration.auth_roles)
    assert_equal :view, @configuration.auth_role_for(:download)
    assert_instance_of RecordingStudio::Hooks, @configuration.hooks
    assert_equal 60, @configuration.rate_limits[:ip][:limit]
    assert_equal 5, @configuration.max_concurrent_builds
    assert_includes @configuration.skip_host_before_actions, :authenticate_user!
    assert_includes @configuration.skip_host_before_actions, :set_current_actor
  end

  def test_merge_accepts_string_keys_and_role_aliases
    @configuration.merge!("auth_roles" => { "download" => "viewer" })

    assert_equal({ download: :view }, @configuration.auth_roles)
  end

  def test_to_h_reports_registered_hook_counts
    @configuration.hooks.before_initialize { nil }
    @configuration.hooks.before_initialize { nil }
    @configuration.hooks.after_service { nil }

    result = @configuration.to_h

    assert_equal 2, result.fetch(:hooks_registered).fetch(:before_initialize)
    assert_equal 1, result.fetch(:hooks_registered).fetch(:after_service)
  end

  def test_configure_without_block_is_safe
    RecordingStudioDownloadable.configure

    assert_kind_of RecordingStudioDownloadable::Configuration, RecordingStudioDownloadable.configuration
  end

  def test_debounce_wait_clamps_to_thirty_through_sixty_seconds
    @configuration.content_change_debounce = 5.seconds
    assert_equal 30.seconds, @configuration.debounce_wait

    @configuration.content_change_debounce = 45.seconds
    assert_equal 45.seconds, @configuration.debounce_wait

    @configuration.content_change_debounce = 120.seconds
    assert_equal 60.seconds, @configuration.debounce_wait
  end
end
