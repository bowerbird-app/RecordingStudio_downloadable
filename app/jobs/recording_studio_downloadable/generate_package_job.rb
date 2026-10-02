# frozen_string_literal: true

module RecordingStudioDownloadable
  class GeneratePackageJob < ApplicationJob
    queue_as :default

    def perform(package_id)
      package = Package.find_by(id: package_id)
      return if package.blank?

      Services::GeneratePackage.call(package: package)
    end
  end
end
