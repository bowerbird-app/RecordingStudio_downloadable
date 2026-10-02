# frozen_string_literal: true

require "test_helper"
require "stringio"
require "zip"

class ZipBuilderTest < Minitest::Test
  def test_builds_zip_with_one_file
    files = [download_file("readme.txt", "hello")]

    entries = zip_entries(files)

    assert_equal ["readme.txt"], entries.keys
    assert_equal "hello", entries["readme.txt"]
  end

  def test_builds_zip_with_many_binary_files
    files = [
      download_file("one.bin", "\x00\x01\x02"),
      download_file("two.pdf", "%PDF-1.4"),
      download_file("clip.mp4", "ftyp")
    ]

    entries = zip_entries(files)

    assert_equal %w[one.bin two.pdf clip.mp4].sort, entries.keys.sort
    assert_equal "\x00\x01\x02", entries["one.bin"]
    assert_equal "%PDF-1.4", entries["two.pdf"]
  end

  def test_deduplicates_filenames_deterministically
    files = [
      download_file("logo.png", "a"),
      download_file("logo.png", "b"),
      download_file("logo.png", "c")
    ]

    entries = zip_entries(files)

    assert_equal %w[logo.png logo-2.png logo-3.png].sort, entries.keys.sort
    assert_equal "a", entries["logo.png"]
    assert_equal "b", entries["logo-2.png"]
    assert_equal "c", entries["logo-3.png"]
  end

  def test_strips_path_traversal_from_entry_names
    files = [download_file("../../secret.txt", "nope")]

    entries = zip_entries(files)

    assert_equal ["secret.txt"], entries.keys
    refute_includes entries.keys.join, ".."
  end

  def test_raises_on_empty_source
    error = assert_raises(RecordingStudioDownloadable::EmptySourceError) do
      RecordingStudioDownloadable::ZipBuilder.new([]).write { |_io| }
    end

    assert_includes error.message, "empty"
  end

  def test_raises_on_missing_source
    file = RecordingStudioDownloadable::DownloadFile.new(
      filename: "gone.txt",
      content_type: "text/plain",
      byte_size: 1,
      checksum: "x",
      identity: "1",
      io_factory: -> { raise Errno::ENOENT }
    )

    assert_raises(RecordingStudioDownloadable::SourceMissingError) do
      RecordingStudioDownloadable::ZipBuilder.new([file]).write { |_io| }
    end
  end

  def test_cleans_up_temp_directory
    files = [download_file("a.txt", "a")]
    before = Dir.glob(File.join(Dir.tmpdir, "rs-downloadable-*"))

    RecordingStudioDownloadable::ZipBuilder.new(files).write do |_io|
      assert Dir.glob(File.join(Dir.tmpdir, "rs-downloadable-*")).size > before.size
    end

    leftover = Dir.glob(File.join(Dir.tmpdir, "rs-downloadable-*")) - before
    assert_empty leftover
  end

  private

  def download_file(name, contents)
    RecordingStudioDownloadable::DownloadFile.new(
      filename: name,
      content_type: "application/octet-stream",
      byte_size: contents.bytesize,
      checksum: contents,
      identity: name,
      io_factory: ->(&block) { block.call(StringIO.new(contents)) }
    )
  end

  def zip_entries(files)
    entries = {}
    RecordingStudioDownloadable::ZipBuilder.new(files).write do |io|
      io.rewind
      Zip::File.open_buffer(io.read) do |zip|
        zip.each { |entry| entries[entry.name] = entry.get_input_stream.read }
      end
    end
    entries
  end
end
