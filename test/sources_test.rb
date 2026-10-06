# frozen_string_literal: true

require "test_helper"

class SourcesTest < Minitest::Test
  FakeRecording = Struct.new(:recordable, keyword_init: true)
  OwnerWithoutManifest = Class.new

  class OwnerWithManifest
    def initialize(entries)
      @entries = entries
    end

    def downloadable_manifest
      @entries
    end
  end

  class RecordingWithManifest
    def initialize(entries)
      @entries = entries
    end

    def recordable
      OwnerWithoutManifest.new
    end

    def downloadable_manifest
      @entries
    end
  end

  def test_collect_dispatches_manifest_without_falling_back_to_attachments
    file = RecordingStudioDownloadable::DownloadFile.from_string(filename: "a.txt", content: "a")
    recording = FakeRecording.new(recordable: OwnerWithManifest.new([file]))

    result = RecordingStudioDownloadable::Sources.collect(:manifest, recording)

    assert_equal [file], result
  end

  def test_collect_rejects_unknown_sources
    error = assert_raises(RecordingStudioDownloadable::UnsupportedOptionError) do
      RecordingStudioDownloadable::Sources.collect(:children, FakeRecording.new(recordable: nil))
    end

    assert_includes error.message, "Unsupported Downloadable source"
  end

  def test_manifest_raises_when_the_method_is_missing
    recording = FakeRecording.new(recordable: OwnerWithoutManifest.new)

    error = assert_raises(RecordingStudioDownloadable::ManifestMissingError) do
      RecordingStudioDownloadable::Sources::Manifest.call(recording)
    end

    assert_includes error.message, "downloadable_manifest"
    assert_includes error.message, "does not fall back to attachments"
  end

  def test_manifest_accepts_the_method_on_the_recording
    file = RecordingStudioDownloadable::DownloadFile.from_string(filename: "a.txt", content: "a")
    recording = RecordingWithManifest.new([file])

    assert_equal [file], RecordingStudioDownloadable::Sources::Manifest.call(recording)
  end

  def test_manifest_rejects_unsupported_entries
    recording = FakeRecording.new(recordable: OwnerWithManifest.new(["not-a-file"]))

    error = assert_raises(RecordingStudioDownloadable::InvalidManifestEntryError) do
      RecordingStudioDownloadable::Sources::Manifest.call(recording)
    end

    assert_includes error.message, "index 0"
    assert_includes error.message, "String"
  end

  def test_manifest_rejects_a_non_array_return
    recording = FakeRecording.new(recordable: OwnerWithManifest.new("oops"))

    error = assert_raises(RecordingStudioDownloadable::InvalidManifestEntryError) do
      RecordingStudioDownloadable::Sources::Manifest.call(recording)
    end

    assert_includes error.message, "Array"
  end

  def test_empty_manifest_is_an_empty_file_list
    recording = FakeRecording.new(recordable: OwnerWithManifest.new([]))

    assert_empty RecordingStudioDownloadable::Sources::Manifest.call(recording)
  end

  def test_nil_manifest_is_an_empty_file_list
    recording = FakeRecording.new(recordable: OwnerWithManifest.new(nil))

    assert_empty RecordingStudioDownloadable::Sources::Manifest.call(recording)
  end

  def test_manifest_preserves_entry_order
    files = [
      RecordingStudioDownloadable::DownloadFile.from_string(filename: "hero.jpg", content: "img"),
      RecordingStudioDownloadable::DownloadFile.from_string(filename: "description.txt", content: "desc"),
      RecordingStudioDownloadable::DownloadFile.from_string(filename: "credits.txt", content: "cred"),
      RecordingStudioDownloadable::DownloadFile.from_string(
        filename: "press-kit.json",
        content_type: "application/json",
        content: '{"ok":true}'
      )
    ]
    recording = FakeRecording.new(recordable: OwnerWithManifest.new(files))

    assert_equal %w[hero.jpg description.txt credits.txt press-kit.json],
                 RecordingStudioDownloadable::Sources::Manifest.call(recording).map(&:filename)
  end
end
