# frozen_string_literal: true

require "test_helper"

class DownloadableCapabilityTest < Minitest::Test
  module Probe
    HostType = Class.new
    OtherType = Class.new
  end

  def setup
    @original_capabilities =
      RecordingStudio.configuration.instance_variable_get(:@capabilities).transform_values(&:dup)
    @original_capability_options =
      RecordingStudio.configuration.instance_variable_get(:@capability_options).dup
    RecordingStudio.configuration.instance_variable_set(:@capabilities, {})
    RecordingStudio.configuration.instance_variable_set(:@capability_options, {})
  end

  def teardown
    RecordingStudio.configuration.instance_variable_set(:@capabilities, @original_capabilities)
    RecordingStudio.configuration.instance_variable_set(:@capability_options, @original_capability_options)
  end

  def test_to_is_the_include_for_wrapper_not_a_fourth_verb
    source = File.read(File.expand_path("../../lib/recording_studio/capabilities/downloadable.rb", __dir__))

    assert_includes source, "action: nil, export_scope: nil, **unknown"
    assert_includes source, "RecordingStudio::Capabilities.include_for(:downloadable, **options.compact)"
    refute_includes source, "enable_capability"
    refute_includes source, "set_capability_options"
    assert_equal %i[default_action_for normalize_export_scope to],
                 RecordingStudio::Capabilities::Downloadable.singleton_methods(false).sort
  end

  def test_to_delegates_to_include_for_with_defaults
    captured_name = nil
    captured_options = nil
    factory = Module.new

    RecordingStudio::Capabilities.stub :include_for, lambda { |name, **options|
      captured_name = name
      captured_options = options
      factory
    } do
      result = RecordingStudio::Capabilities::Downloadable.to

      assert_same factory, result
    end

    assert_equal :downloadable, captured_name
    assert_equal({ source: :attachments, format: :zip }, captured_options)
  end

  def test_to_does_not_enable_until_included
    mixin = RecordingStudio::Capabilities::Downloadable.to

    assert_kind_of Module, mixin
    refute RecordingStudio.capability_enabled?(:downloadable, for: Probe::HostType)
    assert_nil RecordingStudio.capability_options(:downloadable, for: Probe::HostType)
    assert_empty RecordingStudio.configuration.enabled_recordable_types_for(:downloadable)
  end

  def test_including_to_enables_via_include_for_and_sets_options
    Probe::HostType.include(RecordingStudio::Capabilities::Downloadable.to(source: :attachments, format: :zip))

    assert RecordingStudio.capability_enabled?(:downloadable, for: Probe::HostType)
    assert_equal({ source: :attachments, format: :zip },
                 RecordingStudio.capability_options(:downloadable, for: Probe::HostType))
    refute RecordingStudio.capability_enabled?(:downloadable, for: Probe::OtherType)
    assert_equal [Probe::HostType.name],
                 RecordingStudio.configuration.enabled_recordable_types_for(:downloadable)
  end

  def test_installing_the_gem_does_not_enable_it_globally
    assert RecordingStudio.registered_capabilities.key?(:downloadable)
    assert_equal "recording_studio_downloadable",
                 RecordingStudio.registered_capabilities[:downloadable][:source]
    assert_empty RecordingStudio.configuration.enabled_recordable_types_for(:downloadable)
  end

  def test_to_rejects_unknown_options
    error = assert_raises(ArgumentError) do
      RecordingStudio::Capabilities::Downloadable.to(recursive: true)
    end

    assert_includes error.message, "unknown Downloadable option"
  end

  def test_to_accepts_manifest_source
    captured_options = nil
    factory = Module.new

    RecordingStudio::Capabilities.stub :include_for, lambda { |_name, **options|
      captured_options = options
      factory
    } do
      result = RecordingStudio::Capabilities::Downloadable.to(source: :manifest)

      assert_same factory, result
    end

    assert_equal({ source: :manifest, format: :zip }, captured_options)
    assert_includes RecordingStudio::Capabilities::Downloadable::SUPPORTED_SOURCES, :manifest
    assert_includes RecordingStudio::Capabilities::Downloadable::SUPPORTED_SOURCES, :attachments
  end

  def test_to_accepts_action_and_export_scope
    captured_options = nil
    factory = Module.new

    RecordingStudio::Capabilities.stub :include_for, lambda { |_name, **options|
      captured_options = options
      factory
    } do
      result = RecordingStudio::Capabilities::Downloadable.to(
        source: :manifest,
        action: :"presskits.kit_download",
        export_scope: :public
      )

      assert_same factory, result
    end

    assert_equal(
      { source: :manifest, format: :zip, action: :"presskits.kit_download", export_scope: :public },
      captured_options
    )
  end

  def test_default_action_is_derived_from_the_recordable_type
    assert_equal :"workspaces.download",
                 RecordingStudio::Capabilities::Downloadable.default_action_for("Workspace")
    assert_equal :"press_kits.download",
                 RecordingStudio::Capabilities::Downloadable.default_action_for("PressKit")
  end

  def test_to_rejects_unsupported_source_and_format
    error = assert_raises(RecordingStudioDownloadable::UnsupportedOptionError) do
      RecordingStudio::Capabilities::Downloadable.to(source: :children)
    end
    assert_includes error.message, "Unsupported Downloadable source"

    error = assert_raises(RecordingStudioDownloadable::UnsupportedOptionError) do
      RecordingStudio::Capabilities::Downloadable.to(format: :tar)
    end
    assert_includes error.message, "Unsupported Downloadable format"
  end
end
