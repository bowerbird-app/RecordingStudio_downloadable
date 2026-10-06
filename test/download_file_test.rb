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

  def test_from_blob_uses_blob_metadata_and_optional_filename
    blob = FakeBlob.new(id: 42, filename: "stored.bin", content_type: "application/octet-stream",
                        byte_size: 5, checksum: "abc", payload: "hello")
    file = RecordingStudioDownloadable::DownloadFile.from_blob(blob, filename: "hero.jpg")

    assert_equal "hero.jpg", file.filename
    assert_equal "application/octet-stream", file.content_type
    assert_equal 5, file.byte_size
    assert_equal "abc", file.checksum
    assert_equal "active-storage:42", file.identity

    contents = nil
    file.with_io { |io| contents = io.read }
    assert_equal "hello", contents
  end

  def test_from_blob_falls_back_to_the_blob_filename
    blob = FakeBlob.new(id: 7, filename: "logo.svg", content_type: "image/svg+xml",
                        byte_size: 2, checksum: "x", payload: "<>")
    file = RecordingStudioDownloadable::DownloadFile.from_blob(blob)

    assert_equal "logo.svg", file.filename
  end

  def test_from_string_returns_io_when_no_block_is_given
    file = RecordingStudioDownloadable::DownloadFile.from_string(filename: "a.txt", content: "abc")

    assert_equal "abc", file.with_io.read
  end

  def test_from_blob_uses_blob_filename_when_filename_is_blank
    blob = FakeBlob.new(id: 8, filename: "kept.txt", content_type: "text/plain",
                        byte_size: 1, checksum: "y", payload: "z")
    file = RecordingStudioDownloadable::DownloadFile.from_blob(blob, filename: "")

    assert_equal "kept.txt", file.filename
  end

  def test_from_blob_raises_when_the_blob_is_missing_from_storage
    blob = ServicedBlob.new(exists: false)
    file = RecordingStudioDownloadable::DownloadFile.from_blob(blob)

    error = assert_raises(RecordingStudioDownloadable::SourceMissingError) do
      file.with_io(&:read)
    end
    assert_includes error.message, "Missing blob"
  end

  def test_from_blob_treats_storage_errors_as_missing
    blob = ServicedBlob.new(exists: :raise)
    file = RecordingStudioDownloadable::DownloadFile.from_blob(blob)

    assert_raises(RecordingStudioDownloadable::SourceMissingError) do
      file.with_io(&:read)
    end
  end

  def test_from_blob_opens_when_storage_reports_the_blob
    blob = ServicedBlob.new(exists: true)
    file = RecordingStudioDownloadable::DownloadFile.from_blob(blob)

    contents = nil
    file.with_io { |io| contents = io.read }
    assert_equal "a", contents
  end

  FakeBlob = Struct.new(:id, :filename, :content_type, :byte_size, :checksum, :payload, keyword_init: true) do
    def open(&block)
      io = StringIO.new(payload)
      block ? block.call(io) : io
    end
  end

  class ServicedBlob
    attr_reader :id, :filename, :content_type, :byte_size, :checksum

    def initialize(exists:)
      @id = 9
      @filename = "a.txt"
      @content_type = "text/plain"
      @byte_size = 1
      @checksum = "z"
      @exists = exists
    end

    def key
      "k"
    end

    def service
      exists = @exists
      Object.new.tap do |svc|
        svc.define_singleton_method(:exist?) do |_key|
          raise "storage down" if exists == :raise

          exists
        end
      end
    end

    def open(&block)
      block.call(StringIO.new("a"))
    end
  end
end
