# frozen_string_literal: true

require "recording_studio"
require "recording_studio_accessible"

module RecordingStudioDownloadable
  class Error < StandardError; end
  class UnsupportedOptionError < Error; end
  class EmptySourceError < Error; end
  class SourceMissingError < Error; end
  class GenerationError < Error; end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration) if block_given?
    end
  end
end

require "recording_studio_downloadable/version"
require "recording_studio_downloadable/configuration"
require "recording_studio_downloadable/download_file"
require "recording_studio_downloadable/filename"
require "recording_studio_downloadable/fingerprint"
require "recording_studio_downloadable/zip_builder"
require "recording_studio_downloadable/authorization"
require "recording_studio_downloadable/sources/attachments"
require "recording_studio_downloadable/engine"
require "recording_studio/capabilities/downloadable"
