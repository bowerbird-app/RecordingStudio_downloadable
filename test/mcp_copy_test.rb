# frozen_string_literal: true

require "test_helper"

class McpCopyTest < Minitest::Test
  def test_register_is_a_no_op_when_mcp_is_not_loaded
    refute defined?(::RecordingStudioMcp)
    refute RecordingStudioDownloadable::McpCopy.mcp_available?
    assert_empty RecordingStudioDownloadable::McpCopy.tool_names
    assert_nil RecordingStudioDownloadable::McpCopy.register!
  end

  def test_registration_calls_mcp_copy_after_the_api_actions
    source = File.read(
      File.expand_path("../lib/recording_studio_downloadable/api/registration.rb", __dir__)
    )

    assert_includes source, "McpCopy.register!"
    assert source.index("register_action") < source.index("McpCopy.register!")
  end

  def test_gemspec_does_not_depend_on_recording_studio_mcp
    gemspec = File.read(File.expand_path("../recording_studio_downloadable.gemspec", __dir__))
    entry = File.read(File.expand_path("../lib/recording_studio_downloadable.rb", __dir__))
    copy = File.read(File.expand_path("../lib/recording_studio_downloadable/mcp_copy.rb", __dir__))

    refute_match(/add_dependency\s+"recording_studio_mcp"/, gemspec)
    refute_includes entry, 'require "recording_studio_mcp"'
    refute_includes copy, "Gem::Version"
  end
end
