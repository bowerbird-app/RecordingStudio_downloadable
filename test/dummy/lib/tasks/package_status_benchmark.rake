# frozen_string_literal: true

require "digest"
require "stringio"

namespace :recording_studio_downloadable do
  desc "Benchmark ready?, status, and show for a large package. FILE_COUNT=100"
  task benchmark_status: :environment do
    file_count = ENV.fetch("FILE_COUNT", "100").to_i
    ActiveJob::Base.queue_adapter = :inline
    ActionController::Base.allow_forgery_protection = false
    ActiveRecord.query_transformers.delete(ActiveRecord::QueryLogs) if defined?(ActiveRecord::QueryLogs)

    user = workspace = root = kit_recording = nil
    Rails.application.executor.wrap do
      user = User.create!(
        email: "bench-#{SecureRandom.hex(4)}@example.com",
        password: "Password123!",
        password_confirmation: "Password123!"
      )
      workspace = Workspace.create!(name: "Bench workspace #{SecureRandom.hex(4)}")
      root = RecordingStudio.root_recording_for(workspace)
      RecordingStudioAccessible.bootstrap_owner_access!(recording: root, actor: user)
      puts "Building #{file_count} files on the default fingerprint path and the cache key path..."
      file_count.times { |index| bench_attach!(root, user, index) }
      root.downloadable_generate!

      kit = PressKit.create!(name: "Bench kit", description: "Large kit", credits: "Bench")
      kit_recording = RecordingStudio.record!(
        action: "created",
        recordable: kit,
        root_recording: root,
        parent_recording: root,
        actor: user
      ).recording
      file_count.times { |index| bench_attach!(kit_recording, user, index) }
      kit_recording.downloadable_generate!
    end

    session = ActionDispatch::Integration::Session.new(Rails.application)
    session.host! "localhost"
    session.post "/users/sign_in", params: { user: { email: user.email, password: "Password123!" } }
    raise "sign in failed #{session.response.status}" unless session.response.redirect?

    puts "FILE_COUNT=#{file_count}"
    bench_report("default fingerprint", root, session)
    bench_report("cache key hook", kit_recording, session)
  ensure
    bench_cleanup(user, workspace, root, kit_recording)
  end
end

def bench_report(label, recording, session)
  puts "\n== #{label} =="
  recording.reload
  bench_measure("#{label} ready?") { recording.downloadable_ready? }
  bench_measure("#{label} status x1") do
    session.get bench_status_path(recording)
    raise "status #{session.response.status}" unless session.response.successful?
  end
  bench_measure("#{label} status x3") do
    3.times do
      session.get bench_status_path(recording)
      raise "status #{session.response.status}" unless session.response.successful?
    end
  end
  bench_measure("#{label} show ready") do
    session.get bench_show_path(recording)
    raise "show #{session.response.status}" unless session.response.redirect?
  end
end

def bench_measure(label)
  queries = []
  subscriber = nil
  subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
    next if payload[:cached]
    next if payload[:name] == "SCHEMA"
    next if payload[:sql].to_s.match?(/\A(?:BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE)\b/i)

    queries << payload[:sql]
  end
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  yield
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
  puts format("%-32s queries=%4d  time=%7.3fs", label, queries.size, elapsed)
ensure
  ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
end

def bench_status_path(recording)
  "/recording_studio_downloadable/recordings/#{recording.id}/package/status"
end

def bench_show_path(recording)
  "/recording_studio_downloadable/recordings/#{recording.id}/package"
end

def bench_attach!(recording, actor, index)
  content = "file-#{index}-#{SecureRandom.hex(4)}"
  checksum = Digest::MD5.base64digest(content)
  filename = "file-#{index}.txt"
  blob = RecordingStudioAttachable::DirectUpload.prepare!(
    recording: recording,
    actor: actor,
    filename: filename,
    byte_size: content.bytesize,
    checksum: checksum,
    content_type: "text/plain"
  )
  blob.upload(StringIO.new(content), identify: false)
  recording.record_attachment_upload(
    signed_blob_id: RecordingStudioAttachable::DirectUpload.sign(blob),
    actor: actor,
    name: "file-#{index}"
  )
end

def bench_cleanup(user, workspace, root, kit_recording)
  return if user.nil?

  recording_ids = [root&.id, kit_recording&.id].compact
  RecordingStudioDownloadable::Package.where(recording_id: recording_ids).delete_all if recording_ids.any?
  # Recordable snapshots cannot be destroyed. Delete the rows the benchmark created.
  workspace&.delete
  user&.delete
rescue StandardError => e
  warn "benchmark cleanup failed: #{e.class}: #{e.message}"
end
