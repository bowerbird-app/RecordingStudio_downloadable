# frozen_string_literal: true

module RecordingStudioDownloadable
  module Filename
    module_function

    def sanitize(filename)
      name = File.basename(filename.to_s.tr("\\", "/"))
      name = name.gsub(/[\x00-\x1f\x7f]/, "")
      name = name.gsub(%r{[<>:"|?*]}, "_").strip
      name = "file" if name.blank? || name == "." || name == ".."
      name
    end

    def unique_in(filename, used)
      base = sanitize(filename)
      candidate = base
      sequence = 2

      while used.include?(candidate.downcase)
        extension = File.extname(base)
        stem = File.basename(base, extension)
        candidate = "#{stem}-#{sequence}#{extension}"
        sequence += 1
      end

      used << candidate.downcase
      candidate
    end
  end
end
