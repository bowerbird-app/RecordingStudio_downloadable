# frozen_string_literal: true

require_relative "lib/recording_studio_downloadable/version"

Gem::Specification.new do |spec|
  spec.name        = "recording_studio_downloadable"
  spec.version     = RecordingStudioDownloadable::VERSION
  spec.authors     = ["Bowerbird"]
  spec.homepage    = "https://github.com/bowerbird-app/RecordingStudio_downloadable"
  spec.summary     = "Optional Recording Studio addon for packaging recording files into a ZIP"
  spec.description = "Reusable Recording Studio addon that discovers a recording's files, " \
                     "packages them into a downloadable ZIP archive, and serves the archive " \
                     "through an authorized engine route."
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"].reject do |path|
      path == ".cursor" || path.start_with?(".cursor/")
    end
  end

  spec.add_dependency "rails", "~> 8.1.0"
  spec.add_dependency "recording_studio", "~> 4.2"
  spec.add_dependency "recording_studio_accessible"
  spec.add_dependency "recording_studio_attachable"
  spec.add_dependency "rubyzip", ">= 2.3"
end
