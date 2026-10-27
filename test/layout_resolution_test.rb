# frozen_string_literal: true

require "test_helper"
require "action_controller"
require "action_controller/railtie"
require "recording_studio/controller_layout"

helper = Gem.loaded_specs.fetch("recording_studio").full_gem_path
require File.join(helper, "app/helpers/recording_studio/layout_helper")

class LayoutResolutionTest < Minitest::Test
  class HostController < ActionController::Base
    include RecordingStudio::ControllerLayout

    recording_studio_layout { application_layout }

    def application_layout
      "flat_pack_sidebar"
    end
  end

  class EngineController < HostController
    recording_studio_layout { RecordingStudioDownloadable.configuration.layout }
  end

  def setup
    @previous_gem_layout = RecordingStudioDownloadable.configuration.layout
    @previous_core_layout = RecordingStudio.configuration.layout
    RecordingStudioDownloadable.configuration.layout = nil
    RecordingStudio.configuration.layout = nil
  end

  def teardown
    RecordingStudioDownloadable.configuration.layout = @previous_gem_layout
    RecordingStudio.configuration.layout = @previous_core_layout
  end

  def test_engine_controller_prefers_the_gem_layout
    RecordingStudio.configuration.layout = "host_shell"
    RecordingStudioDownloadable.configuration.layout = "downloadable_shell"

    assert_equal "downloadable_shell", EngineController.new.recording_studio_resolved_layout
  end

  def test_engine_controller_falls_through_to_the_core_layout
    RecordingStudio.configuration.layout = "host_shell"

    assert_equal "host_shell", EngineController.new.recording_studio_resolved_layout
  end

  def test_engine_controller_uses_the_default_layout_when_both_settings_are_nil
    assert_equal RecordingStudio::DEFAULT_LAYOUT, EngineController.new.recording_studio_resolved_layout
  end

  def test_false_layout_does_not_fall_through
    RecordingStudioDownloadable.configuration.layout = false
    RecordingStudio.configuration.layout = "host_shell"

    assert_equal false, EngineController.new.recording_studio_resolved_layout
  end

  def test_host_controller_resolves_its_own_layout_name
    assert_equal "flat_pack_sidebar", HostController.new.recording_studio_resolved_layout
  end
end
