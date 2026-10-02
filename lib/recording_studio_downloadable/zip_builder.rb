# frozen_string_literal: true

require "fileutils"
require "tmpdir"
require "zip"

module RecordingStudioDownloadable
  class ZipBuilder
    def initialize(files)
      @files = Array(files)
    end

    def write
      raise EmptySourceError, "Cannot generate an empty ZIP archive" if files.empty?

      Dir.mktmpdir("rs-downloadable-") do |dir|
        zip_path = File.join(dir, "archive.zip")
        write_archive(zip_path)
        payload = File.binread(zip_path)
        yield StringIO.new(payload)
      end
    end

    private

    attr_reader :files

    def write_archive(zip_path)
      used_names = []

      open_zip(zip_path) do |zip|
        files.each do |file|
          write_entry(zip, Filename.unique_in(file.filename, used_names), file)
        end
      end
    end

    def write_entry(zip, entry_name, file)
      opened = false

      file.with_io do |io|
        raise SourceMissingError, "Missing source for #{file.filename}" if io.nil?

        opened = true
        zip.get_output_stream(entry_name) { |output| IO.copy_stream(io, output) }
      end

      raise SourceMissingError, "Missing source for #{file.filename}" unless opened
    rescue Errno::ENOENT
      raise SourceMissingError, "Missing source for #{file.filename}"
    end

    def open_zip(zip_path, &)
      if zip_open_uses_create_keyword?
        Zip::File.open(zip_path, create: true, &)
      else
        Zip::File.open(zip_path, Zip::File::CREATE, &)
      end
    end

    def zip_open_uses_create_keyword?
      Zip::File.method(:open).parameters.any? { |kind, name| kind == :key && name == :create }
    end
  end
end
