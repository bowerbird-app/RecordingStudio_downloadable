RecordingStudioDownloadable install complete.

Next steps:

1. Review config/initializers/recording_studio_downloadable.rb.
2. Install migrations with `bin/rails generate recording_studio_downloadable:migrations`.
3. Apply them with `bin/rails db:migrate`.
4. Ensure Active Storage is installed so package archives can be stored. Attachable is required for
   `source: :attachments`. `source: :manifest` uses a host `#downloadable_manifest` of DownloadFile objects.
5. Opt host recordables in with `include RecordingStudio::Capabilities::Downloadable.to`.
   Installing this gem does not enable `:downloadable`. Pass `action:` for a named Accessible action
   (default is derived from the recordable type, e.g. `workspaces.download`). Use `source: :attachments`
   (default) or `source: :manifest`.
6. Configure each download action on Accessible 0.14+:

   ```ruby
   RecordingStudioAccessible.configure do |config|
     config.action_audiences[:"workspaces.download"] = {
       allowed: %i[granted],
       default: :granted,
       granted_roles: %i[view edit admin],
       granted_override: true,
       manage_role: :admin
     }
   end
   ```

   Add `public` to `allowed` only when anonymous downloads should succeed. Domain conditions belong on
   the recordable as `downloadable_available_for?(actor:, action:)`.
7. Mount routes are added at the configured mount path. Adjust auth, layout, and current actor integration
   to match your host app. The engine skips common host auth/tenant callbacks (`authenticate_user!` and
   similar) so public audiences can reach show/create/status. Every endpoint still authorizes through
   Accessible `authorized_action?`. Keep `recording_studio_recordable` declarations on host types.
8. Pin the Stimulus package controller so “Preparing…” polls `GET …/package/status` (same authorization
   as the ZIP) and starts the authorized `GET …/package` when the package is `ready`. Anonymous and
   non-granted actors never enqueue a build; missing or stale packages return a not-ready response.
   Failed packages show Retry instead of spinning forever. The installer adds the importmap pin and
   `lazyLoadControllersFrom` when those host files exist.
9. Large ZIP downloads: authorized `GET …/package` redirects to a short-lived signed Active Storage URL
   (`blob.url`, default 5 minutes). That URL is a bearer link until it expires, even if access is later
   revoked. Bytes stream from Disk or R2/S3. The app does not buffer the archive with `blob.download`.
