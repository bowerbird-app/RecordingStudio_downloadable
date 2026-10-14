# frozen_string_literal: true

require "pagy"

module RecordingStudioDownloadable
  class DownloadLogsController < ApplicationController
    include Pagy::Backend

    PAGE_SIZE = 20

    def index
      @recording = find_recording
      authorize_view_logs!(@recording)
      @stats = DownloadStats.new(@recording)
      @filters = DownloadLogFilters.new(@recording, filter_params)
      @pagy, @logs = pagy(@filters.relation, limit: PAGE_SIZE)
    end

    private

    def filter_params
      params.permit(:download, :person, :from, :to)
    end
  end
end
