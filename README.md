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
| **Downloadable** | Normalising a file list, fingerprints, ZIP generation, archive storage, cache/fingerprint lifecycle, archive download, download logs, history, and stats |
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

Anonymous requests are first-class. The engine skips inherited host auth and tenant callbacks such as `authenticate_user!` (see `config.skip_host_before_actions`). **Every** engine endpoint (`show`, `create`, `status`, download history) still authorizes. Skipping `authenticate_user!` is not enough on its own — tenant loaders that require a signed-in user must be skipped or written to tolerate a nil actor.

`show`, `create`, and `status` authorize the recording's download action. Download history authorizes `:"downloadable.view_logs"` instead. A person who can download cannot open history unless they can also edit. History is a RecordingStudioAdmin screen, so the actor also has to pass that mount's sign-in.

## Download logs

A download log is operational exhaust: an authorised download was started. It is not a recording, a child recording, a package, or a row in `recording_studio_events`. `log_event!` is the revision stream and is the wrong tool here.

Rows live in `recording_studio_downloadable_download_logs` (`RecordingStudioDownloadable::DownloadLog`). The table copies Core's event columns that still make sense (who, impersonator, when) and leaves out recordable snapshot columns. There is no `updated_at`. Rows are append-only: update and destroy raise. Trash leaves the rows in place. Destroying the recording deletes them (`dependent: :delete_all`).

| Column | Notes |
| --- | --- |
| `recording_id` | The item that was downloaded |
| `root_recording_id` | The recording's root, backfilled from `recording_studio_recordings`. New rows stamp it on insert. |
| `action` | The download action, such as `presskits.kit_download` |
| `export_scope` | Package identity, default `public` |
| `actor_type` / `actor_id` | Who downloaded. Null means anonymous |
| `impersonator_type` / `impersonator_id` | `Current.impersonator`, when set |
| `ip_address` | Stored, never shown on the history screen |
| `user_agent` | Stored, truncated to 512 characters, never shown on the history screen |
| `metadata` | Opaque host snapshot from the download gate. Flat JSON, sanitized. Never shown on the history screen |
| `occurred_at` | When the download started. Sort key |

The only insert is in `PackagesController#show`, immediately before the signed `blob.url` redirect. By then the recording exists and is downloadable, the actor is authorized, any download gate is satisfied, the rate limit passed, and the package is ready and fingerprint-current. Nothing else writes a row: enqueue, status polling, ZIP jobs, denied requests, 429s, an unsatisfied gate, empty or stale or failed packages, button impressions, sign-in, or access-request clicks. The insert includes sanitized `metadata` from the gate when the gate implements `metadata_for`.

A row means the download was started. It does not mean the transfer finished. Repeats are logged again. A failed insert is reported and does not block the ZIP. The signed URL is never stored.

```ruby
recording.downloadable_download_logs # newest last in the association; history sorts newest first
```

Downloadable registers this table with RecordingStudioLogs as an unpartitioned, indefinite raw log (`partition_interval: nil`, `root_column: :root_recording_id`). Existing rows stay in `recording_studio_downloadable_download_logs`. The table is not copied or partitioned. There is no daily summary table.

History, Metrics charts, the pre-download gate, and rate limits read raw download logs. Do not schedule Logs partition jobs for this table. Logs retention never drops a log with no aggregations. The gem's own pruner still deletes.

## Access-aware button

`recording_studio_downloadable_button` asks `RecordingStudioDownloadable::Authorization.allowed?`. Allowed people get the same button, polling, and download behaviour as before. Denied people get the component registered for that action, or nothing. The endpoints still authorize on their own.

Register by action. `Downloadable.to` does not accept a component option.

```ruby
RecordingStudioDownloadable.configure do |config|
  config.register_access_denied_component :"presskits.kit_download", PressKits::DownloadAccessComponent
end
```

The component is initialized with `recording:`, `actor:`, and `action:`. Downloadable only knows allowed versus denied. It does not invent an access-state machine. Hosts decide what “ask for access” looks like.

## Pre-download gate

A host can pause a download until its own steps are done. Downloadable does not know the questions. An action with no registered gate behaves as before.

```ruby
RecordingStudioDownloadable.configure do |config|
  config.register_download_gate :"presskits.kit_download", Presskits::KitDownloadGate
end
```

Register a class or any object. Every method is optional:

| Method | Role |
| --- | --- |
| `satisfied?(recording:, actor:, request:)` | `true` when the host steps are done. Omit it and the gate does not block. |
| `continuation_url(recording:, actor:, request:)` | Where an HTML `GET` of the package goes while the gate is still open. |
| `component` | ViewComponent class, initialized with `recording:`, `actor:`, and `action:`. |
| `metadata_for(recording:, actor:)` | Flat hash copied onto the download log when a real download starts. |

`PackagesController#show` checks the gate after authorization and before the rate limit, the empty check, enqueue, and the log. While the gate is unsatisfied:

- HTML `GET` redirects to `continuation_url`.
- An iframe or XHR (`Accept: application/json`, `Sec-Fetch-Dest: iframe`, or `X-Requested-With`) gets `409` with `{ "continuation_url": "..." }`.
- The autostart session flag is cleared, so the next render does not iframe the form.
- The rate limit is not incremented, nothing is enqueued, and no download log is written.

`create` and `status` stay gate-free. The Stimulus controller, on a `409` from `show`, fires a cancelable `recording-studio-downloadable:download-gate` event with `detail.continuationUrl`. If the page calls `preventDefault`, the top window stays put and the host can open its own UI (a modal, for example). Otherwise the top window goes to `continuation_url`. The form is never loaded in the hidden iframe.

When the person is allowed and the gate is unsatisfied, `recording_studio_downloadable_button` renders `component` (if the gate provides one) instead of the download control, and it does not mount the poller. That component can be an ordinary Download button which opens the host's modal. Allowed and satisfied keeps the current button. Denied still uses the access-denied component. The dummy's Gated Download workspace does this: the button opens a confirmation modal. After the checkbox, that modal mounts the same package poller and shows a progress bar for waiting, building, and ready. When the archive download starts, the bar is replaced with a started confirmation. Pass a block to `recording_studio_downloadable_button` to supply that chrome; without a block the helper still renders the Download button. A `data-downloadable-progress` element inside the poller opts into this status UI. A cached ZIP may cross the bar quickly, then still shows the ready line before the confirmation. The poller writes every status, including ready, into `[data-downloadable-progress-label]`.

In-progress answers stay with the host. Downloadable does not open a draft row.

### Metadata

`metadata` is `jsonb`, default `{}`, with no GIN index. `DownloadLog.record!` keeps a flat snapshot and drops the rest:

- at most 32 keys
- each key matches `[a-z0-9_]{1,40}`
- values are scalars: string, number, boolean, or null
- strings at most 200 characters
- the JSON document at most 2KB

Dropped data is reported. The download still proceeds. Downloadable does not interpret the keys. History stays when and who, the same way it hides IP addresses. Metrics are unchanged. Rows stay append-only.

## Download history

History is a RecordingStudioAdmin screen, `download_logs`, not an engine controller. Downloadable registers the screen and a `downloads` section when Admin is loaded. It does not mount Admin. The host does:

```ruby
recording_studio_admin_for :admin, at: "/admin"

RecordingStudioAdmin.configure do |config|
  config.authentication_method = :authenticate_user!
  config.current_actor_method = :current_user
  config.access_recording_resolver = lambda do |context|
    if RecordingStudioDownloadable::Admin.recording_id?(context)
      RecordingStudioDownloadable::Admin.recording_for(context)
    else
      context.controller.current_root_recording
    end
  end
end
```

`recording_id` is the item whose logs you are opening. Without that param, the resolver should return the current root. A missing or trashed id stays unresolved so Admin refuses the page. The default query is `access_recording.downloadable_download_logs`.

Add `scope=subtree` to count that recording and its Core descendants (`descendant_ids(include_self: true)`). Do not use `root_recording_id` for this rollup. The client cannot pass recording ids. Optional `recordable_type` further limits which recordings in that tree are included. One type or several. Unknown types are ignored. If every type is unknown, the table is empty. Hosts keep that param on links. The subtree screen has a What filter of concrete items in that tree, labeled with each recording's name. Pick one to see only that item's logs. All restores the subtree, still honoring `recordable_type` when it is set. Single-recording history has no What filter.

```
/admin/screens/download_logs?recording_id=:id
/admin/screens/download_logs?recording_id=:id&scope=subtree
/admin/screens/download_logs?recording_id=:id&scope=subtree&recordable_type=PressKit
/admin/screens/download_logs?recording_id=:id&scope=subtree&recordable_type[]=PressKit&recordable_type[]=Page
```

A host that rolls kit downloads up under a parent recording (a press center that is not itself downloadable) links with subtree and the kit types. Downloadable does not know those product types.

Admin's own gate is still `required_access_role` (default `:view`) on that recording. Downloadable then requires `:"downloadable.view_logs"` on the **anchor** only (`visible_if` on the screen, and the query returns nothing when it fails). Child recordings are not checked. The action defaults to role `:edit`, so edit and admin can open history and view cannot. It does not fall back to `:view` and it does not reuse the download check. Hosts override it through Accessible, for example `config.action_audiences[:"downloadable.view_logs"]`. A signed-in person who passes Admin's `:view` role and fails `downloadable.view_logs` gets Admin's not-found response. Admin has no per-screen Accessible action.

```ruby
recording_studio_downloadable_history_link(recording)
recording_studio_downloadable_history_link(
  recording,
  scope: :subtree,
  recordable_type: %w[PressKit Page]
)
```

The helper renders nothing unless Admin is loaded and the current person can view history. Omit `scope` and the recording must be downloadable, same as before. With `scope: :subtree` the recording does not need to be downloadable. The link is `/admin/screens/download_logs?recording_id=…` when the host mounted Admin as `:admin` at `/admin`. Subtree adds `scope=subtree` and any `recordable_type` values.

Admin also requires the current root (Root Switchable) to be that recording's root. A history link for another workspace is refused until the person switches. The dummy starts on Studio Workspace when the signed-in person can open it, so the home page History link matches.

The screen uses Admin's layout, inline filters, summary count, line chart, and paginated table (20 rows). Filters are a period preset, group by, and person. Subtree adds What, a select of items in that tree. The presets are Last 7 days, Last 4 weeks (the default), Last 3 months, Last 12 months, and All time. Columns are when and who (or “Anonymous”), newest first. Subtree adds a What column with the item name. IP addresses, user agents, metadata, and the download action stay off the screen.

Admin's `date_range` filter always renders a free start/end calendar, and its preset list cannot be replaced from a screen. `Period` also has no all-time key (`last_7_days`, `last_4_weeks`, `last_3_months`, and `last_12_months` do parse). The screen therefore uses a select whose values are those Period keys plus `all_time`. Select filters do not apply `default:`, and a missing `period` param would show “All” over an unfiltered table, so the query stamps `last_4_weeks` before the filters run. `last_4_weeks` is Period's window: today minus 28 days through today. All time leaves `occurred_at` unbounded. The chart still has to hand Metrics a start and end, and Metrics refuses a reporting period longer than its maximum (about a year), so an All time chart start is pulled forward to fit.

When `RecordingStudio_metrics` is loaded, Downloadable registers `download_logs.total` (count) and `download_logs.over_time` (timeseries on `occurred_at`). The chart calls `RecordingStudioMetrics::Admin.chart_series` with `MetricsRegistration.context_for(recording:, actor:, relation:)`. That context uses scope `:root` and an `authorized_relation` already limited to the history query (this recording, or the subtree, and the active filters when the screen draws the chart). Passing the Admin context straight into `chart_series` would also send the root recording, and Metrics would treat the log table as a recordable and return no points.

`chart_series` returns `{ x:, y: }` points (RecordingStudio_metrics 0.5.0). The screen hands that series to Admin. The counts stay the same.

## Presskits

Presskits owns the denied-state component and where the history link sits. Downloadable does not depend on Presskits. A host wires it like this:

```ruby
RecordingStudioDownloadable.configure do |config|
  config.register_access_denied_component :"presskits.kit_download", PressKits::DownloadAccessComponent
end
```

`PressKits::DownloadAccessComponent` should accept `recording:`, `actor:`, and `action:`. `PublicShowComponent#show_download?` should keep rendering `recording_studio_downloadable_button` for people who are denied, and let the helper choose the button or the fallback. The editor Downloads section can drop in `recording_studio_downloadable_history_link(recording)`.

Presskits also owns the pre-download form. Register it on the same action:

```ruby
RecordingStudioDownloadable.configure do |config|
  config.register_download_gate :"presskits.kit_download", Presskits::KitDownloadGate
end
```

`KitDownloadGate` answers `satisfied?`, sends people to `continuation_url`, optionally renders `component`, and returns `metadata_for` when the ZIP actually starts. The form and any in-progress answers stay in Presskits. Downloadable only stores the sanitized snapshot on the download log.

`ImageArchivesController` still sends image archives with `send_data` and a `kit_view_full` check. That path skips Downloadable authorization, rate limits, the download gate, and the download log. Routing those archives through a Downloadable action (or calling the same authorize, gate, rate-limit, and log hook) is a Presskits change, and it is larger than a registration line, so it is not done in this gem.

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

1. Add the gem (and Attachable + Accessible 0.14+ + Logs) to the host app.
2. `bin/rails generate recording_studio_downloadable:install`
3. `bin/rails generate recording_studio_logs:migrations` if Logs run tables are not already present
4. `bin/rails generate recording_studio_downloadable:migrations`
5. `bin/rails db:migrate`
6. List each download action in Accessible `config.action_audiences`.
7. Opt each recordable in with `.to`.

This dummy pins Recording Studio dummy GitHub tag `v6.1.0`, Accessible dummy GitHub tag `v0.22.0`, Trashable dummy GitHub tag `v0.12.0` (query-only; required by Accessible `>= 0.17`), Cache dummy GitHub tag `v0.5.1`, Logs dummy GitHub tag `v0.7.0`, Root Switchable dummy GitHub tag `v0.11.0`, Metrics dummy GitHub tag `v0.6.1` (required by Root Switchable `>= 0.7` and Attachable `>= 0.14`), Admin dummy GitHub tag `v2.7.0` (download history screen), FlatPack commit `1fcbafe94f8eb118f0a22182f63f5110fcc97a56` (`0.1.319`), and Attachable `v0.22.0`.

## Dummy app

Dummy credentials (`test/dummy/config/credentials.yml.enc`) are encrypted with the shared RecordingStudio_* development master key. Set `RAILS_MASTER_KEY` or put that key in `test/dummy/config/master.key` (gitignored). Keep the encrypted file; do not generate a per-repo dummy key.

Sign in at `/users/sign_in` (`admin@admin.com` / `Password`). The home page and `/pages` show a Download control.

Clicking Download `POST`s generation, then Stimulus polls `GET …/package/status` until the package is `ready` (or `failed`). When ready, the authorized `GET …/package` starts in a hidden iframe so the ZIP downloads without replacing the page. If source files changed since the last ZIP, the package is **stale**: authorized actors (including anonymous when the audience is `public`) enqueue one rebuild; the old ZIP is not served.

Customer-facing copy uses `recording_studio.downloadable.*` in `config/locales/en.yml`. Every `Copy.t` call passes English `default:` so a host locale without a fallback never shows "translation missing". Hosts override by defining the same nested keys in their own `config/locales`. Authorization, rate-limit, empty-source, and archive-too-large raise/persist sites stay locale-aware `Copy.t` (with English `default:`). Stimulus keeps English JS defaults when data attributes are absent.

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

Rate limiting is a thin adapter over `RecordingStudioCache::RateLimiter` (fixed windows, keys under `rs_downloadable:rate:…`) with `store:` set to `config.cache_store` (`config.cache` if set, else `Rails.cache`). NullStore and other unusable caches still short-circuit (no limiting). Counter keys also get a TTL equal to the period — storage cleanup only; counting is unchanged because the window is in the key name. Use a store that supports `increment`. Exceeded limits return 429. Oversize archives fail generation without serving a partial ZIP.

## Upgrade notes

Hosts on 0.2.x need a new migration (`action` + `export_scope` on `recording_studio_downloadable_packages`). Existing packages are backfilled to the default action for that recording's type and `public` scope.

Pin Accessible to GitHub tag `v0.22.0`, Trashable to `v0.12.0` (`require: false`; needs Recording Studio `>= 6.1.0`), Cache to `v0.5.1`, and Logs to `v0.7.0` (gemspec `>= 0.4.1, < 1.0`). List each download action in `config.action_audiences`. Until an action is configured, Downloadable keeps the previous role mapping (`auth_roles`, default `download: :view`) so existing granted users can still download.

Hosts moving to 0.8.0 keep their download log rows. See [UPGRADING.md](UPGRADING.md).

`source: :attachments` and `source: :manifest` are unchanged. Pass `action:` on `.to` when the derived name is not the Accessible action you configured.
