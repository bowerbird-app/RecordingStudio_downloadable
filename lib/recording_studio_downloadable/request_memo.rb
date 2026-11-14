# frozen_string_literal: true

module RecordingStudioDownloadable
  # Per-request memo for package status checks. Nested calls share one store.
  # The store is cleared when the outermost block ends, so a later change in
  # the same process is visible. The build job reads its cache key with
  # fresh: true and does not use this store.
  module RequestMemo
    module_function

    def with_request_memo
      outer = Thread.current[:rs_downloadable_memo_depth].to_i
      Thread.current[:rs_downloadable_memo] ||= {}
      Thread.current[:rs_downloadable_memo_depth] = outer + 1
      yield
    ensure
      Thread.current[:rs_downloadable_memo_depth] = outer
      Thread.current[:rs_downloadable_memo] = nil if outer.zero?
    end

    def store
      Thread.current[:rs_downloadable_memo]
    end
  end
end
