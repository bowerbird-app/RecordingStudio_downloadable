# frozen_string_literal: true

# R2 rejects some AWS SDK default checksum headers. Apply only when the dummy
# is pointed at the S3-compatible service in storage.yml.
if %w[amazon cloudflare_r2].include?(ENV["DUMMY_ACTIVE_STORAGE_SERVICE"].to_s)
  require "aws-sdk-s3"

  Aws.config.update(
    request_checksum_calculation: "when_required",
    response_checksum_validation: "when_required"
  )
end
