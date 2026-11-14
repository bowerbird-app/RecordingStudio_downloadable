# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"
require "digest"
require "stringio"

class PressKitCacheKeyTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper

  setup do
    @user = User.create!(
      email: "kit-key-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!"
    )
    sign_in @user
    workspace = Workspace.create!(name: "Cache key workspace #{SecureRandom.hex(4)}")
    root = RecordingStudio.root_recording_for(workspace)
    RecordingStudioAccessible.bootstrap_owner_access!(recording: root, actor: @user)
    press_kit = PressKit.create!(name: "Cache kit", description: "Hello", credits: "Ada")
    @recording = RecordingStudio.record!(
      action: "created",
      recordable: press_kit,
      root_recording: root,
      parent_recording: root,
      actor: @user
    ).recording
    @workspace_recording = root
    attach_text!(@recording, filename: "logo.txt", contents: "mark")
    attach_text!(@workspace_recording, filename: "notes.txt", contents: "notes")
  end

  teardown do
    restore_manifest_count!
  end

  test "the press kit hook changes when the copy or a file changes" do
    before = @recording.downloadable_cache_key
    @recording.root_recording.revise(@recording, actor: @user) do |kit|
      kit.description = "Goodbye"
    end
    refute_equal before, @recording.reload.downloadable_cache_key

    with_file = @recording.downloadable_cache_key
    attach_text!(@recording, filename: "extra.txt", contents: "more")
    refute_equal with_file, @recording.reload.downloadable_cache_key
  end

  test "press kit status does not build the manifest and workspace status still does" do
    perform_enqueued_jobs { @recording.downloadable_generate! }
    perform_enqueued_jobs { @workspace_recording.downloadable_generate! }
    assert @recording.reload.downloadable_ready?
    assert @workspace_recording.reload.downloadable_ready?

    count_manifest_calls do
      get recording_studio_downloadable.recording_package_status_path(@recording), as: :json
      assert_response :success
      assert_equal true, response.parsed_body["ready"]
      assert_equal 0, Thread.current[:press_kit_manifest_calls]
    end

    collects = count_file_collects do
      get recording_studio_downloadable.recording_package_status_path(@workspace_recording), as: :json
    end
    assert_response :success
    assert_equal true, response.parsed_body["ready"]
    assert_equal 1, collects[:calls]
  end

  private

  def attach_text!(recording, filename:, contents:)
    checksum = Digest::MD5.base64digest(contents)
    blob = RecordingStudioAttachable::DirectUpload.prepare!(
      recording: recording,
      actor: @user,
      filename: filename,
      byte_size: contents.bytesize,
      checksum: checksum,
      content_type: "text/plain"
    )
    blob.upload(StringIO.new(contents), identify: false)
    recording.record_attachment_upload(
      signed_blob_id: RecordingStudioAttachable::DirectUpload.sign(blob),
      actor: @user,
      name: File.basename(filename, ".*")
    )
  end

  def count_manifest_calls
    Thread.current[:press_kit_manifest_calls] = 0
    return if PressKit.method_defined?(:downloadable_manifest_without_count)

    PressKit.alias_method :downloadable_manifest_without_count, :downloadable_manifest
    PressKit.define_method(:downloadable_manifest) do
      Thread.current[:press_kit_manifest_calls] = Thread.current[:press_kit_manifest_calls].to_i + 1
      downloadable_manifest_without_count
    end
    yield
  end

  def count_file_collects
    counter = { calls: 0 }
    singleton = RecordingStudioDownloadable::Services::CollectFiles.singleton_class
    singleton.alias_method(:call_without_status_count, :call)
    singleton.define_method(:call) do |*args, **kwargs, &block|
      counter[:calls] += 1
      call_without_status_count(*args, **kwargs, &block)
    end
    yield
    counter
  ensure
    if singleton.method_defined?(:call) && singleton.instance_method(:call).owner == singleton
      singleton.remove_method(:call)
    end
    singleton.remove_method(:call_without_status_count) if singleton.method_defined?(:call_without_status_count)
  end

  def restore_manifest_count!
    return unless PressKit.method_defined?(:downloadable_manifest_without_count)

    PressKit.alias_method :downloadable_manifest, :downloadable_manifest_without_count
    PressKit.remove_method(:downloadable_manifest_without_count)
    Thread.current[:press_kit_manifest_calls] = nil
  end
end
