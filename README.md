# RecordingStudio Downloadable

Recording Studio 4.2 addon that packages a recording’s files into a downloadable ZIP.

Installing this gem does **not** enable the capability. Host recordables opt in:

```ruby
include RecordingStudio::Capabilities::Downloadable.to(
  source: :attachments,
  format: :zip
)
```

`Downloadable.to` is valid with no arguments. V1 implements `source: :attachments` and `format: :zip` only.

## Responsibility boundary

| Addon | Owns |
| --- | --- |
| **Attachable** | Individual files: upload, replace, remove, metadata, previews, single-file download |
| **Downloadable** | Identifying the file set, ZIP generation, archive storage, cache/fingerprint lifecycle, archive download |
| **Accessible** | Whether the actor may download the **owner recording** |

Downloadable does not move ZIP into Attachable, does not depend on Presskits or Sidekiq, and uses Active Job.

Authorization mirrors Attachable: action `:download` is mapped to an Accessible **role** (`auth_roles`, default `download: :view`), then Downloadable calls `RecordingStudioAccessible::Authorization.allowed?(actor:, recording:, role:)`. This gem does not change Accessible.

Accessible has no first-class `:download` role in the current published release (`view` / `edit` / `admin`). Downloadable therefore uses a role mapping, not an Accessible action registry.

### Accessible gap (do not patch Accessible from this gem)

Published Accessible (`v0.11.0` as pinned by this dummy) exposes:

- `RecordingStudioAccessible::Authorization.allowed?(actor:, recording:, role:)`
- roles `view` / `edit` / `admin`

It does **not** expose a `:download` role or an action registry that addons can register into. Downloadable therefore:

1. Treats `:download` as a **Downloadable action**.
2. Maps that action to an Accessible role via `config.auth_roles` (default `download: :view`) or a per-include `auth_roles:` override.
3. Asks Accessible only `allowed?(actor:, recording:, role:)`.

If Accessible later adds a dedicated download role or action, this gem can remap `auth_roles` without changing Accessible from this repository.

## Host example

```ruby
class Project < ApplicationRecord
  recording_studio_recordable label: "Project", root: true
  RecordingStudio.enable_capability(:accessible, on: self)

  include RecordingStudio::Capabilities::Attachable.to(
    allowed_content_types: ["*/*"],
    max_file_size: 25.megabytes
  )
  include RecordingStudio::Capabilities::Downloadable.to
end
```

```ruby
recording = RecordingStudio.root_recording_for(project)
recording.downloadable?              # => true
recording.downloadable_files         # DownloadFile value objects (direct attachments only)
recording.downloadable_empty?
recording.downloadable_generate!     # enqueues Active Job; hosts do not call the job
recording.downloadable_ready?
recording.downloadable_package       # persisted Package (archive blob + fingerprint + state)
recording.downloadable_download_path # engine route; authorizes in the controller
```

Direct attachments only. Original blobs, not image variants. Inactive/trashed attachments are excluded. An empty file set does not produce a ZIP; the download endpoint returns not found.

## Install

1. Add the gem (and Attachable + Accessible) to the host app.
2. `bin/rails generate recording_studio_downloadable:install`
3. `bin/rails generate recording_studio_downloadable:migrations`
4. `bin/rails db:migrate`
5. Opt each recordable in with `.to`.

dummy GitHub tag `v4.2.2`, dummy GitHub tag `v0.11.0`, dummy GitHub tag `v0.5.1`, dummy GitHub tag `v0.1.198`, Attachable `v0.7.0`.

## Dummy app

Sign in at `/users/sign_in` (`admin@admin.com` / `Password`). The home page and `/pages` show a Download control.

Clicking Download `POST`s generation, then Stimulus polls `GET …/package/status` until the package is `ready` (or `failed`). When ready, the authorized `GET …/package` starts in a hidden iframe so the ZIP downloads without replacing the page. If attachments changed since the last ZIP, the package is **stale**: Download regenerates instead of 404ing. Accessible still gates `:download`.

## Serving large ZIPs

`GET …/package` checks Accessible `:download`, then **redirects** to a short-lived signed Active Storage URL (`blob.url`, `expires_in: ActiveStorage.urls_expire_in`). The browser (or R2) streams bytes from storage. The app does not call `blob.download` or `send_data` on the archive.

On S3/R2 the signed GET includes `response-content-disposition` so the filename stays `Something.zip`. Disk service uses the authenticated `/rails/active_storage/disk/...` URL with the same disposition in the signed token.
