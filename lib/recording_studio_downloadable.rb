# frozen_string_literal: true

require "recording_studio"
require "recording_studio_accessible"
require "i18n"

locale_file = File.expand_path("../config/locales/en.yml", __dir__)
I18n.load_path << locale_file unless I18n.load_path.include?(locale_file)
I18n.backend.load_translations if I18n.backend.respond_to?(:load_translations)

module RecordingStudioDownloadable
  class Error < StandardError; end
  class UnsupportedOptionError < Error; end
  class EmptySourceError < Error; end
  class SourceMissingError < Error; end
  class GenerationError < Error; end
  class ManifestMissingError < Error; end
  class InvalidManifestEntryError < Error; end
  class RateLimitedError < Error; end
  class ConcurrentBuildLimitError < Error; end
  class ArchiveTooLargeError < Error; end

  # blob.url rejects expires_in of 0 or less. Fall back when the host sets
  # ActiveStorage.urls_expire_in to 0/nil (Rails' usual default is 5 minutes).
  # The signed URL is a bearer link: anyone with it can download until it expires,
  # even if access is revoked afterwards.
  SIGNED_URL_EXPIRES_IN = 5.minutes

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
require "recording_studio_downloadable/copy"
require "recording_studio_downloadable/configuration"
require "recording_studio_downloadable/download_file"
require "recording_studio_downloadable/filename"
require "recording_studio_downloadable/fingerprint"
require "recording_studio_downloadable/zip_builder"
require "recording_studio_downloadable/rate_limiter"
require "recording_studio_downloadable/authorization"
require "recording_studio_downloadable/invalidation"
require "recording_studio_downloadable/sources"
require "recording_studio_downloadable/engine"
require "recording_studio/capabilities/downloadable"
