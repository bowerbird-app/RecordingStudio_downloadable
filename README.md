# Recording Studio Downloadable

Recording Studio 4.2 addon that packages files into a downloadable ZIP.

Installing this gem does **not** enable the capability. Host recordables opt in:

```ruby
include RecordingStudio::Capabilities::Downloadable.to(
  source: :attachments,
  format: :zip
)
```

```ruby
include RecordingStudio::Capabilities::Downloadable.to(
  source: :manifest,
  format: :zip,
  action: :"presskits.kit_download"
)
```

`Downloadable.to` is valid with no arguments. Defaults are `source: :attachments` and `format: :zip`. The download **action** defaults to a name derived from the recordable type (`Workspace` → `:"workspaces.download"`). `export_scope` defaults to `:public`. V1 implements `source: :attachments` / `:manifest` and `format: :zip` only.

## Responsibility boundary

| Addon | Owns |
| --- | --- |
| **Attachable** | Individual uploaded files: upload, replace, remove, metadata, previews, single-file download |
| **Downloadable** | Normalising a file list, fingerprints, ZIP generation, archive storage, cache/fingerprint lifecycle, archive download |
| **Host / domain gem** | A `downloadable_manifest` when the ZIP must mix files Downloadable cannot discover on its own; domain guards such as `downloadable_available_for?` |
| **Accessible** | Whether the actor may perform this recording's download **action** |

Attachable owns uploaded files. Downloadable owns package creation and delivery. It does not know Press Kits, credits, people, or any other domain shape. When a composite package needs a specific set of stored files and generated text, the host (or another Recording Studio gem) supplies a generic list of downloadable files.

Downloadable does not move ZIP into Attachable, does not depend on Presskits or Sidekiq, and uses Active Job.

Each download type is a named Accessible action. Rules, caches, and limits for `:"presskits.kit_download"` never apply to `:"account.private_data_export"`.

## Authorization

Accessible 0.14+ is the authorization layer. Downloadable calls `RecordingStudioAccessible.authorized_action?` for the recording's download action, then the optional domain hook.

```ruby
RecordingStudioAccessible.configure do |config|
  config.action_audiences[:"presskits.kit_download"] = {
    allowed: %i[signed_in granted], # add `public` for anonymous downloads
    default: :granted,
    granted_roles: %i[download edit admin],
    granted_override: true,
    manage_role: :admin
  }
end

class Kit < ApplicationRecord
  include RecordingStudio::Capabilities::Downloadable.to(
    source: :manifest,
    action: :"presskits.kit_download"
  )

  def downloadable_available_for?(actor:, action:)
    currently_published?
  end
end
```

`authorize_with` still overrides the Accessible check when you need a host adapter. `config.auth_roles` (`download: :view` by default) is only a fallback for actions that are not listed in `action_audiences` and have no `define_action` policy.

`downloadable_available_for?(actor:, action:)` on the recordable (or recording) runs **after** the audience check. Exceptions deny. Publication and other domain conditions stay out of Accessible.

Anonymous requests are first-class. The engine skips inherited host auth and tenant callbacks such as `authenticate_user!` (see `config.skip_host_before_actions`). **Every** engine endpoint (`show`, `create`, `status`) still authorizes the same way. Skipping `authenticate_user!` is not enough on its own — tenant loaders that require a signed-in user must be skipped or written to tolerate a nil actor.

### Who may generate a ZIP

Anyone who passes the full authorization for that action may trigger a build: Accessible `authorized_action?` plus the optional `downloadable_available_for?` domain hook. That includes a nil actor when the action's audience is `public`.

Builds enqueue when no current package exists or the stored one is stale. One in-flight build is shared per `recording + action + export_scope + format`; concurrent `show` / `create` / `status` requests get a not-ready or preparing response and wait for the same job. Unauthorized requests never enqueue. `show` and `create` are rate-limited per action (IP, actor, recording). `status` polling may enqueue only when authorized and idle (missing or stale, never a failed retry), so it stays un-rate-limited.

Before serving, Downloadable verifies the stored fingerprint against the current manifest (action and export scope included). A mismatch is not served.

## Package identity

Packages are unique on `recording_id + action + export_scope + format`. Existing rows are backfilled to the type's default action and `public` scope. The content fingerprint also includes action and export scope, so a ZIP built for one action or scope is never treated as current for another.

## Sources

### `source: :attachments`

Direct Attachable children only. Original blobs, not image variants. Inactive/trashed attachments are excluded. Downloadable does not walk descendants.

```ruby
class Project < ApplicationRecord
  recording_studio_recordable label: "Project", root: true
  RecordingStudio.enable_capability(:accessible, on: self)

  include RecordingStudio::Capabilities::Attachable.to(
    allowed_content_types: ["*/*"],
    max_file_size: 25.megabytes
  )
  include RecordingStudio::Capabilities::Downloadable.to(
    source: :attachments,
    format: :zip
  )
end
```

### `source: :manifest`

Downloadable asks the recordable for `#downloadable_manifest` (or the recording, if that is where the host defined it). The method must return an array of `RecordingStudioDownloadable::DownloadFile` objects. There is no fallback to attachments.

Use this when the ZIP should contain a chosen mix of stored blobs and generated content (text, JSON, CSV, and so on). Fingerprints use content identity, not timestamps, so a changed `credits.txt` or a replaced blob makes the cached ZIP stale.

```ruby
class Kit < ApplicationRecord
  recording_studio_recordable label: "Kit", root: false, allowed_parent_types: ["Project"]

  include RecordingStudio::Capabilities::Downloadable.to(
    source: :manifest,
    format: :zip,
    action: :"presskits.kit_download"
  )

  def downloadable_manifest
    [
      RecordingStudioDownloadable::DownloadFile.from_blob(hero_image.file.blob, filename: "hero.jpg"),
      RecordingStudioDownloadable::DownloadFile.from_string(
        filename: "description.txt",
        content_type: "text/plain",
        content: description
      )
    ]
  end
end
```

That Press Kit-shaped list is only an example. Downloadable never learns what a Press Kit is. Helpers:

```ruby
RecordingStudioDownloadable::DownloadFile.from_blob(blob, filename: "hero.jpg")
RecordingStudioDownloadable::DownloadFile.from_string(
  filename: "credits.txt",
  content_type: "text/plain",
  content: credits
)
```

An empty manifest behaves like an empty attachment set: no ZIP, and the download endpoint returns not found. A missing `#downloadable_manifest` or an entry that is not a `DownloadFile` raises a Downloadable error.

## Host API

```ruby
recording = RecordingStudio.root_recording_for(project)
recording.downloadable?              # => true
recording.downloadable_action        # => :"projects.download" (or the action: passed to .to)
recording.downloadable_export_scope  # => :public
recording.downloadable_files         # DownloadFile value objects
recording.downloadable_empty?
recording.downloadable_generate!(action:, export_scope:, ...) # enqueue a build
recording.downloadable_invalidate!(immediate: true)          # drop/stop serving the ZIP
recording.downloadable_ready?
recording.downloadable_package       # persisted Package (archive blob + fingerprint + state)
recording.downloadable_download_path # engine route; authorizes in the controller
recording.downloadable_source        # :attachments or :manifest
```

`recording.downloadable_generate!(action:, export_scope:)` enqueues a build. `recording.downloadable_invalidate!(immediate: true)` drops the current ZIP so it is not served. Hosts call these from their own subscribers. Downloadable does not depend on Publishable.

`downloadable_invalidate!(immediate: true)` marks the cached ZIP unusable immediately (asset removal, unpublish, visibility, or authorization changes). Ordinary content changes debounce a rebuild for 30–60 seconds (`config.content_change_debounce`, default 45). Attachment observers enqueue a rebuild only when a package row already exists; the first ZIP comes from an authorized generate (HTTP or `downloadable_generate!`).

## Host publish and unpublish signals

Downloadable stays independent of Publishable. Wire your own events to the recording API:

```ruby
# Enqueue a build when the host considers the item current.
recording.downloadable_generate!(
  action: recording.downloadable_action,
  export_scope: recording.downloadable_export_scope
)

# Stop serving the current ZIP immediately.
recording.downloadable_invalidate!(immediate: true)
```

Example only — RecordingStudio_publishable v0.7.0 emits `published.recording_studio_publishable` and `unpublished.recording_studio_publishable`. A host gem can subscribe and call generate or invalidate on the recording in the payload. Do not add a Publishable dependency to Downloadable.

## Install

1. Add the gem (and Attachable + Accessible 0.14+) to the host app.
2. `bin/rails generate recording_studio_downloadable:install`
3. `bin/rails generate recording_studio_downloadable:migrations`
4. `bin/rails db:migrate`
5. List each download action in Accessible `config.action_audiences`.
6. Opt each recordable in with `.to`.

This dummy pins Recording Studio dummy GitHub tag `v4.4.0`, Accessible dummy GitHub tag `v0.14.0`, Root Switchable dummy GitHub tag `v0.6.0`, FlatPack dummy GitHub tag `v0.1.213`, and Attachable `v0.13.0`.

## Dummy app

Dummy credentials (`test/dummy/config/credentials.yml.enc`) are encrypted with the shared RecordingStudio_* development master key. Set `RAILS_MASTER_KEY` or put that key in `test/dummy/config/master.key` (gitignored). Keep the encrypted file; do not generate a per-repo dummy key.

Sign in at `/users/sign_in` (`admin@admin.com` / `Password`). The home page and `/pages` show a Download control.

Clicking Download `POST`s generation, then Stimulus polls `GET …/package/status` until the package is `ready` (or `failed`). When ready, the authorized `GET …/package` starts in a hidden iframe so the ZIP downloads without replacing the page. If source files changed since the last ZIP, the package is **stale**: authorized actors (including anonymous when the audience is `public`) enqueue one rebuild; the old ZIP is not served.

Customer-facing copy uses `recording_studio.downloadable.*` in `config/locales/en.yml`.

## Serving large ZIPs

`GET …/package` checks the download action, then **redirects** to a short-lived signed Active Storage URL (`blob.url`). Expiry uses `ActiveStorage.urls_expire_in` when it is a positive duration; if that config is `0` or blank, the gem uses `SIGNED_URL_EXPIRES_IN` (5 minutes) so signing never raises. The browser (or R2) streams bytes from storage. The app does not call `blob.download` or `send_data` on the archive.

On S3/R2 the signed GET includes `response-content-disposition` so the filename stays `Something.zip`. Disk service uses the authenticated `/rails/active_storage/disk/...` URL with the same disposition in the signed token.

**The signed URL is a bearer link.** Anyone who has it can download the archive until it expires, even if the actor is later signed out or their access is revoked. Keep the TTL short.

## Limits

Limits are keyed by action so one download type cannot exhaust another.

```ruby
RecordingStudioDownloadable.configure do |config|
  config.rate_limits = {
    ip: { limit: 60, period: 1.minute },
    actor: { limit: 60, period: 1.minute },
    recording: { limit: 30, period: 1.minute }
  }
  config.max_concurrent_builds = 5
  config.max_zip_bytes = 500.megabytes
end
```

Rate limiting uses `Rails.cache` (or `config.cache`). Use a store that supports `increment`. Exceeded limits return 429. Oversize archives fail generation without serving a partial ZIP.

## Upgrade notes

Hosts on 0.2.x need a new migration (`action` + `export_scope` on `recording_studio_downloadable_packages`). Existing packages are backfilled to the default action for that recording's type and `public` scope.

Pin Accessible to GitHub tag `v0.14.0`. List each download action in `config.action_audiences`. Until an action is configured, Downloadable keeps the previous role mapping (`auth_roles`, default `download: :view`) so existing granted users can still download.

`source: :attachments` and `source: :manifest` are unchanged. Pass `action:` on `.to` when the derived name is not the Accessible action you configured.
