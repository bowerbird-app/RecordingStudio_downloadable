# frozen_string_literal: true

require "test_helper"
require "digest"
require "stringio"

class DownloadFileTest < Minitest::Test
  def test_from_string_builds_a_generated_file_with_content_fingerprint
    file = RecordingStudioDownloadable::DownloadFile.from_string(
      filename: "credits.txt",
      content_type: "text/plain",
      content: "Hello"
    )

    assert_equal "credits.txt", file.filename
    assert_equal "text/plain", file.content_type
    assert_equal 5, file.byte_size
    assert_equal Digest::SHA256.base64digest("Hello"), file.checksum
    assert_equal "generated:credits.txt:#{Digest::SHA256.hexdigest('Hello')}", file.identity

    contents = nil
    file.with_io { |io| contents = io.read }
    assert_equal "Hello", contents
  end

  def test_from_string_fingerprint_input_changes_with_content
    hello = RecordingStudioDownloadable::DownloadFile.from_string(filename: "description.txt", content: "Hello")
    world = RecordingStudioDownloadable::DownloadFile.from_string(filename: "description.txt", content: "Hello world")
    same = RecordingStudioDownloadable::DownloadFile.from_string(filename: "description.txt", content: "Hello")

    refute_equal hello.identity, world.identity
    refute_equal hello.checksum, world.checksum
    assert_equal hello.identity, same.identity
    assert_equal RecordingStudioDownloadable::Fingerprint.call([hello]),
                 RecordingStudioDownloadable::Fingerprint.call([same])
    refute_equal RecordingStudioDownloadable::Fingerprint.call([hello]),
                 RecordingStudioDownloadable::Fingerprint.call([world])
  end

  def test_from_blob_requires_a_blob
    error = assert_raises(ArgumentError) do
      RecordingStudioDownloadable::DownloadFile.from_blob(nil)
    end

    assert_includes error.message, "blob is required"
  end
end
