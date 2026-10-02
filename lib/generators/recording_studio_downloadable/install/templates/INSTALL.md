RecordingStudioDownloadable install complete.

Next steps:

1. Review config/initializers/recording_studio_downloadable.rb.
2. Install migrations with `bin/rails generate recording_studio_downloadable:migrations`.
3. Apply them with `bin/rails db:migrate`.
4. Ensure Active Storage and RecordingStudio Attachable are installed for `source: :attachments`.
5. Opt host recordables in with `include RecordingStudio::Capabilities::Downloadable.to`.
   Installing this gem does not enable `:downloadable`.
6. Mount routes are added at the configured mount path. Adjust auth, layout, and current actor integration
   to match your host app. Keep `recording_studio_recordable` declarations on host types.

