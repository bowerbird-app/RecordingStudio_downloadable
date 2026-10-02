# frozen_string_literal: true

require "test_helper"

class FilenameTest < Minitest::Test
  def test_sanitize_uses_basename_and_strips_traversal
    assert_equal "secret.txt", RecordingStudioDownloadable::Filename.sanitize("../../secret.txt")
    assert_equal "secret.txt", RecordingStudioDownloadable::Filename.sanitize("foo\\..\\secret.txt")
  end

  def test_sanitize_replaces_unsafe_characters
    assert_equal "a_b.txt", RecordingStudioDownloadable::Filename.sanitize("a:b.txt")
    assert_equal "file", RecordingStudioDownloadable::Filename.sanitize("..")
  end

  def test_unique_in_appends_incrementing_suffix
    used = []
    first = RecordingStudioDownloadable::Filename.unique_in("logo.png", used)
    second = RecordingStudioDownloadable::Filename.unique_in("logo.png", used)
    third = RecordingStudioDownloadable::Filename.unique_in("LOGO.PNG", used)

    assert_equal "logo.png", first
    assert_equal "logo-2.png", second
    assert_equal "LOGO-3.PNG", third
  end
end
