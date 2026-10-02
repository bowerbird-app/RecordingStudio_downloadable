# frozen_string_literal: true

module RecordingStudioDownloadable
  module Services
    class BaseService
      class Result
        attr_reader :value, :error, :errors

        def initialize(success:, value: nil, error: nil, errors: [])
          @success = success
          @value = value
          @error = error
          @errors = errors
        end

        def success?
          @success
        end

        def failure?
          !@success
        end

        def value!
          raise error if failure?

          value
        end
      end

      class << self
        def call(*, **, &)
          new(*, **).call(&)
        end
      end

      def call
        result = perform
        yield(result) if block_given?
        result
      end

      private

      def perform
        raise NotImplementedError, "#{self.class}#perform must be implemented"
      end

      def success(value = nil)
        Result.new(success: true, value: value)
      end

      def failure(error, errors: [])
        error_message = error.is_a?(Exception) ? error.message : error
        Result.new(success: false, error: error_message, errors: errors)
      end
    end
  end
end
