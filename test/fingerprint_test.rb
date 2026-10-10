# frozen_string_literal: true

require "test_helper"

class FingerprintTest < Minitest::Test
  def test_is_stable_for_the_same_files_in_any_order
    first = download_file("a.txt", "a", identity: "1")
    second = download_file("b.txt", "b", identity: "2")

    assert_equal RecordingStudioDownloadable::Fingerprint.call([first, second]),
                 RecordingStudioDownloadable::Fingerprint.call([second, first])
  end

  def test_changes_when_checksum_or_filename_changes
    original = download_file("a.txt", "aaa", identity: "1")
    renamed = download_file("b.txt", "aaa", identity: "1")
    replaced = download_file("a.txt", "bbb", identity: "1")

    refute_equal RecordingStudioDownloadable::Fingerprint.call([original]),
                 RecordingStudioDownloadable::Fingerprint.call([renamed])
    refute_equal RecordingStudioDownloadable::Fingerprint.call([original]),
                 RecordingStudioDownloadable::Fingerprint.call([replaced])
  end

  def test_changes_when_action_or_export_scope_changes
    file = download_file("a.txt", "aaa", identity: "1")

    public_workspace = RecordingStudioDownloadable::Fingerprint.call(
      [file], action: :"workspaces.download", export_scope: :public
    )
    public_kit = RecordingStudioDownloadable::Fingerprint.call(
      [file], action: :"presskits.kit_download", export_scope: :public
    )
    draft_workspace = RecordingStudioDownloadable::Fingerprint.call(
      [file], action: :"workspaces.download", export_scope: :draft
    )

    refute_equal public_workspace, public_kit
    refute_equal public_workspace, draft_workspace
  end

  private

  def download_file(name, contents, identity:)
    RecordingStudioDownloadable::DownloadFile.new(
      filename: name,
      content_type: "text/plain",
      byte_size: contents.bytesize,
      checksum: contents,
      identity: identity,
      io_factory: ->(*) {}
    )
  end
end
