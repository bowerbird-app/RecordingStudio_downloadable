# frozen_string_literal: true

module RecordingStudioDownloadable
  class ApplicationJob < ActiveJob::Base
    retry_on ActiveRecord::Deadlocked
    discard_on ActiveJob::DeserializationError
  end
end
