# frozen_string_literal: true

require "test_helper"

class DownloadableSourcesTest < ActiveSupport::TestCase
  test "dummy workspace stays on attachments while the gem accepts a manifest source" do
    assert_equal({ source: :attachments, format: :zip },
                 RecordingStudio.capability_options(:downloadable, for: Workspace))
    assert_includes RecordingStudio::Capabilities::Downloadable::SUPPORTED_SOURCES, :manifest
    assert_includes RecordingStudio::Capabilities::Downloadable::SUPPORTED_SOURCES, :attachments
  end
end
