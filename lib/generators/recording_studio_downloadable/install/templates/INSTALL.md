RecordingStudioDownloadable install complete.

Next steps:

1. Review config/initializers/recording_studio_downloadable.rb.
2. Install migrations with `bin/rails generate recording_studio_downloadable:migrations`.
3. Apply them with `bin/rails db:migrate`.
4. Ensure Active Storage is installed so package archives can be stored. Attachable is required for
   `source: :attachments`. `source: :manifest` uses a host `#downloadable_manifest` of DownloadFile objects.
5. Opt host recordables in with `include RecordingStudio::Capabilities::Downloadable.to`.
   Installing this gem does not enable `:downloadable`. Use `source: :attachments` (default) or
   `source: :manifest`.
6. Mount routes are added at the configured mount path. Adjust auth, layout, and current actor integration
   to match your host app. Keep `recording_studio_recordable` declarations on host types.
7. Pin the Stimulus package controller so “Preparing…” polls `GET …/package/status` (Accessible `:download`)
   and starts the authorized `GET …/package` ZIP when the package is `ready`. Failed packages show Retry
   instead of spinning forever. The installer adds the importmap pin and `lazyLoadControllersFrom` when
   those host files exist.
8. Large ZIP downloads: authorized `GET …/package` redirects to a short-lived signed Active Storage URL
   (`blob.url`). Bytes stream from Disk or R2/S3. The app does not buffer the archive with `blob.download`.

