# RecordingStudio Downloadable

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
  format: :zip
)
```

`Downloadable.to` is valid with no arguments. Defaults are `source: :attachments` and `format: :zip`. V1 implements those two sources and `format: :zip` only.

## Responsibility boundary

| Addon | Owns |
| --- | --- |
| **Attachable** | Individual uploaded files: upload, replace, remove, metadata, previews, single-file download |
| **Downloadable** | Normalising a file list, fingerprints, ZIP generation, archive storage, cache/fingerprint lifecycle, archive download |
| **Host / domain gem** | A `downloadable_manifest` when the ZIP must mix files Downloadable cannot discover on its own |
| **Accessible** | Whether the actor may download the **owner recording** |

Attachable owns uploaded files. Downloadable owns package creation and delivery. It does not know Press Kits, credits, people, or any other domain shape. When a composite package needs a specific set of stored files and generated text, the host (or another Recording Studio gem) supplies a generic list of downloadable files.

Downloadable does not move ZIP into Attachable, does not depend on Presskits or Sidekiq, and uses Active Job.

Authorization mirrors Attachable: action `:download` is mapped to an Accessible **role** (`auth_roles`, default `download: :view`), then Downloadable calls `RecordingStudioAccessible::Authorization.allowed?(actor:, recording:, role:)`. This gem does not change Accessible.

Accessible has no first-class `:download` role in the current published release (`view` / `edit` / `admin`). Downloadable therefore uses a role mapping, not an Accessible action registry.

### Accessible gap (do not patch Accessible from this gem)

Published Accessible (`v0.11.1` as pinned by this dummy) exposes:

- `RecordingStudioAccessible::Authorization.allowed?(actor:, recording:, role:)`
- roles `view` / `edit` / `admin`

It does **not** expose a `:download` role or an action registry that addons can register into. Downloadable therefore:

1. Treats `:download` as a **Downloadable action**.
2. Maps that action to an Accessible role via `config.auth_roles` (default `download: :view`) or a per-include `auth_roles:` override.
3. Asks Accessible only `allowed?(actor:, recording:, role:)`.

If Accessible later adds a dedicated download role or action, this gem can remap `auth_roles` without changing Accessible from this repository.

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
    format: :zip
  )

  def downloadable_manifest
    [
      RecordingStudioDownloadable::DownloadFile.from_blob(hero_image.file.blob, filename: "hero.jpg"),
      RecordingStudioDownloadable::DownloadFile.from_string(
        filename: "description.txt",
        content_type: "text/plain",
        content: description
      ),
      RecordingStudioDownloadable::DownloadFile.from_string(
        filename: "credits.txt",
        content_type: "text/plain",
        content: credits
      ),
      RecordingStudioDownloadable::DownloadFile.from_string(
        filename: "press-kit.json",
        content_type: "application/json",
        content: JSON.pretty_generate(serialized_press_kit)
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
recording.downloadable_files         # DownloadFile value objects
recording.downloadable_empty?
recording.downloadable_generate!     # enqueues Active Job; hosts do not call the job
recording.downloadable_ready?
recording.downloadable_package       # persisted Package (archive blob + fingerprint + state)
recording.downloadable_download_path # engine route; authorizes in the controller
recording.downloadable_source        # :attachments or :manifest
```

## Install

1. Add the gem (and Attachable + Accessible) to the host app.
2. `bin/rails generate recording_studio_downloadable:install`
3. `bin/rails generate recording_studio_downloadable:migrations`
4. `bin/rails db:migrate`
5. Opt each recordable in with `.to`.

dummy GitHub tag `v4.4.0`, dummy GitHub tag `v0.11.1`, dummy GitHub tag `v0.5.1`, dummy GitHub tag `v0.1.198`, Attachable `v0.7.1`.

## Dummy app

Dummy credentials (`test/dummy/config/credentials.yml.enc`) are encrypted with the shared RecordingStudio_* development master key. Set `RAILS_MASTER_KEY` or put that key in `test/dummy/config/master.key` (gitignored). Keep the encrypted file; do not generate a per-repo dummy key.

Sign in at `/users/sign_in` (`admin@admin.com` / `Password`). The home page and `/pages` show a Download control.

Clicking Download `POST`s generation, then Stimulus polls `GET …/package/status` until the package is `ready` (or `failed`). When ready, the authorized `GET …/package` starts in a hidden iframe so the ZIP downloads without replacing the page. If source files changed since the last ZIP, the package is **stale**: Download regenerates instead of 404ing. Accessible still gates `:download`.

## Serving large ZIPs

`GET …/package` checks Accessible `:download`, then **redirects** to a short-lived signed Active Storage URL (`blob.url`). Expiry uses `ActiveStorage.urls_expire_in` when it is a positive duration; if that config is `0` or blank, the gem uses `SIGNED_URL_EXPIRES_IN` (5 minutes) so signing never raises. The browser (or R2) streams bytes from storage. The app does not call `blob.download` or `send_data` on the archive.

On S3/R2 the signed GET includes `response-content-disposition` so the filename stays `Something.zip`. Disk service uses the authenticated `/rails/active_storage/disk/...` URL with the same disposition in the signed token.

## Upgrade notes

Hosts that already use `source: :attachments` need no code changes. Behaviour of direct attachments, fingerprints, package lifecycle, ZIP sanitisation, authorization, and delivery is unchanged.

To ship a composite ZIP, opt that recordable into `source: :manifest` and implement `#downloadable_manifest`. Do not expect attachments to be included unless the manifest lists them.
