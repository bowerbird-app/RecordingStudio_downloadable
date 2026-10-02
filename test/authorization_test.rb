# frozen_string_literal: true

require "test_helper"

class AuthorizationTest < Minitest::Test
  FakeRecording = Struct.new(:recordable_type, keyword_init: true)

  def setup
    @original_configuration = RecordingStudioDownloadable.instance_variable_get(:@configuration)
    RecordingStudioDownloadable.instance_variable_set(:@configuration, RecordingStudioDownloadable::Configuration.new)
  end

  def teardown
    RecordingStudioDownloadable.instance_variable_set(:@configuration, @original_configuration)
  end

  def test_allowed_is_false_when_downloadable_is_not_enabled
    recording = FakeRecording.new(recordable_type: "Project")

    RecordingStudio.configuration.stub(:capability_enabled?, false) do
      RecordingStudioAccessible::Authorization.stub(:allowed?, true) do
        refute RecordingStudioDownloadable::Authorization.allowed?(
          action: :download,
          actor: Object.new,
          recording: recording
        )
      end
    end
  end

  def test_authorize_raises_when_capability_is_not_enabled
    recording = FakeRecording.new(recordable_type: "Project")

    RecordingStudio.configuration.stub(:capability_enabled?, false) do
      error = assert_raises(RecordingStudioDownloadable::Authorization::CapabilityNotEnabledError) do
        RecordingStudioDownloadable::Authorization.authorize!(
          action: :download,
          actor: Object.new,
          recording: recording
        )
      end

      assert_includes error.message, "Downloadable capability is not enabled"
    end
  end

  def test_allowed_maps_download_action_to_accessible_role
    recording = FakeRecording.new(recordable_type: "Project")
    captured = nil

    RecordingStudio.configuration.stub(:capability_enabled?, true) do
      RecordingStudioAccessible::Authorization.stub :allowed?, lambda { |**kwargs|
        captured = kwargs
        true
      } do
        assert RecordingStudioDownloadable::Authorization.allowed?(
          action: :download,
          actor: :user,
          recording: recording
        )
      end
    end

    assert_equal({ actor: :user, recording: recording, role: :view }, captured)
  end

  def test_allowed_uses_custom_adapter_and_merged_role_overrides
    recording = FakeRecording.new(recordable_type: "Project")
    captured = nil
    adapter = lambda do |**kwargs|
      captured = kwargs
      true
    end

    RecordingStudio.configuration.stub(:capability_enabled?, true) do
      result = RecordingStudioDownloadable::Authorization.allowed?(
        action: :download,
        actor: :user,
        recording: recording,
        capability_options: {
          authorize_with: adapter,
          auth_roles: { download: :admin }
        }
      )

      assert result
    end

    assert_equal :admin, captured[:role]
    assert_equal :download, captured[:action]
  end

  def test_required_role_for_prefers_capability_overrides
    role = RecordingStudioDownloadable::Authorization.required_role_for(
      :download,
      capability_options: { auth_roles: { download: :admin } }
    )

    assert_equal :admin, role
  end

  def test_authorize_raises_when_adapter_denies
    recording = FakeRecording.new(recordable_type: "Project")

    RecordingStudio.configuration.stub(:capability_enabled?, true) do
      error = assert_raises(RecordingStudioDownloadable::Authorization::NotAuthorizedError) do
        RecordingStudioDownloadable::Authorization.authorize!(
          action: :download,
          actor: :user,
          recording: recording,
          capability_options: { authorize_with: ->(**) { false } }
        )
      end

      assert_includes error.message, "Not authorized to download"
    end
  end
end
