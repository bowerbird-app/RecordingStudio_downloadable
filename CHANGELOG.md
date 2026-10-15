# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0/).

## [Unreleased]

## [0.7.0] - 2026-10-15

### Added

- `register_download_gate` so a host can pause `PackagesController#show` until its own steps are done. HTML redirects to `continuation_url`. Iframe and XHR requests get `409` with `{ "continuation_url": "..." }`. The autostart flag is cleared. Rate limits, enqueue, and the download log wait until the gate is satisfied. `create` and `status` stay gate-free.
- The download button renders the gate component, and does not mount the poller, while the person is allowed and the gate is unsatisfied.
- The package Stimulus controller sends the top window to `continuation_url` on a `409` from `show`.
- `jsonb` `metadata` on `recording_studio_downloadable_download_logs` (default `{}`, no GIN index). `DownloadLog.record!` keeps a flat sanitized snapshot from `metadata_for` at the existing log point, immediately before the signed archive URL. Bad entries are dropped and reported. The download still proceeds. History stays when and who.

### Upgrade notes

- Bump to `0.7.0` and run the new download-logs migration (`metadata jsonb`, default `{}`). Existing rows get `{}`. Nothing else is backfilled.
- Actions with no registered gate behave as before. Hosts that want a pre-download step call `register_download_gate`. In-progress answers stay on the host. Downloadable does not open a draft row.
- Metadata keys must match `[a-z0-9_]{1,40}` (at most 32), values must be scalars, strings at most 200 characters, and the document at most 2KB. History and metrics do not show metadata.
- Presskits image archives still bypass the gate until Presskits routes them through a Downloadable action. Presskits builds the form and registers `Presskits::KitDownloadGate`.

## [0.6.0] - 2026-10-14

### Added

- Append-only `recording_studio_downloadable_download_logs` for authorised downloads that were started. One insert in `PackagesController#show`, immediately before the signed archive URL. Insert failures are reported and do not block the ZIP.
- Access-aware `recording_studio_downloadable_button`. Denied people see the component registered for that action, or nothing.
- Download history is a RecordingStudioAdmin screen (`download_logs`) when that gem is loaded. It keeps Accessible action `:"downloadable.view_logs"` (default role `:edit`). Filters are period presets (Last 7 days, Last 4 weeks by default, Last 3 months, Last 12 months, All time), group by, and person. The table is when and who. The chart uses `RecordingStudioMetrics::Admin.chart_series`.
- Optional Metrics registration (`download_logs.total`, `download_logs.over_time`) when RecordingStudio_metrics is loaded. Callers pass `MetricsRegistration.context_for`, which scopes the relation to the recording.

### Upgrade notes

- Bump to `0.6.0` and run the new download-logs migration. Nothing is backfilled. Download logs are new exhaust, not recordings and not `recording_studio_events` rows.
- Register a denied component per download action if the button should offer something other than silence.
- History is separate from download permission. Mount RecordingStudioAdmin and resolve `recording_id` to the recording in `access_recording_resolver` (see the README). Override `:"downloadable.view_logs"` through Accessible `action_audiences` when edit/admin is the wrong bar. There is no engine `/downloads` route.
- History filters are `period` (`last_7_days`, `last_4_weeks`, `last_3_months`, `last_12_months`, `all_time`; missing means `last_4_weeks`), `group_by`, and `person`.

## [0.5.0] - 2026-10-13

### Changed

- Rate limiting now uses shared `RecordingStudioCache::RateLimiter` (recording_studio_cache `~> 0.5`, git tag `v0.5.0`) instead of a bespoke counter. Public `RateLimiter` methods, `config.rate_limits`, `config.cache` / `cache_store`, key shapes (`rs_downloadable:rate:…`), fixed windows, 429 responses, blank/nil/`<= 0` limit skips, blank-key skips, NullStore / unusable-cache short-circuit, string periods (via `to_i`), and fail-open `StandardError` handling match main.
- Storage-only: counter keys now also receive a TTL equal to the period (shared `rails_cache` backend). Counting is unchanged because the fixed-window segment is already part of the key name; keys simply expire instead of lingering until eviction.

### Upgrade notes

- Bump to `0.5.0`. No migration.
- Pin `recording_studio_cache` to GitHub tag `v0.5.0` (not RubyGems), gemspec `~> 0.5`.
- Rate-limit config and counting behavior stay the same. Cache entries for counters may disappear after one period (storage cleanup only).

## [0.4.0] - 2026-10-13

### Added

- English Rails I18n keys for non-view copy under `recording_studio.downloadable` (controller flashes, button labels, Stimulus poll strings, and raise/persist error notices) resolve through `Copy.t` with English `default:` so a host locale without a fallback never shows "translation missing".
- Host English override coverage: test-only fixture `test/dummy/test/locales/downloadable_host_override.en.yml` loaded via `I18n.backend.load_translations` (no `I18n.load_path` mutation) plus a real-page assert.
- Always-loaded boot-order guard `test/dummy/config/locales/recording_studio_downloadable_host.en.yml` for the rarely shown `notices.timeout` key, with a render assert on the home Download control data attribute.
- Locale regression: every `lib/**/*.rb` file must not mention `i18n.load_path` / `I18n.load_path`.
- Render-level asserts for Download button labels, Stimulus data values, and create flashes (`Building ZIP…` / `Download is ready.`).
- Locale-aware asserts for authorization / rate-limit / empty-source / archive-too-large `Copy.t` call sites (French override plus English `default:`).

### Changed

- Controller flashes, helper button labels, Stimulus data attributes, and the existing raise/persist `Copy.t` call sites (authorization, rate limits, empty source, archive-too-large) pass English `default:` on every lookup. Locale-aware messages stay as on 0.3.0; English output stays byte-identical.
- Removed the explicit `I18n.load_path` append from `lib/recording_studio_downloadable.rb`. The engine exposes `config/locales` through Rails as usual (dummy boot-order host override proves host locale files still win).

### Upgrade notes

- Bump to `0.4.0`. No migration.
- English hosts need no change. Copy `recording_studio.downloadable.*` keys into host locale files when translating.
- Hosts override by defining the same nested keys in their own `config/locales`.
- Generator CLI text, developer `ArgumentError`s, unsupported-source / missing-manifest messages, icon/style tokens, and stored archive filenames stay untranslated.
- Stimulus JS keeps English defaults for `readyText` / `preparingText` / `retryText` / `notReadyText` / `timeoutText` when data attributes are absent.

## [0.3.0] - 2026-10-10

### Added
- Per-action download types via `Downloadable.to(..., action:)`. The default action is derived from the recordable type (`Workspace` → `:"workspaces.download"`).
- Package identity `recording_id + action + export_scope + format`, with a migration that backfills existing rows to the default action and `public` scope.
- Authorization through Accessible 0.14 `authorized_action?` and `config.action_audiences`. Optional `downloadable_available_for?(actor:, action:)` runs after the audience check.
- Anonymous-safe engine endpoints: inherited host auth/tenant callbacks are skipped; every `show` / `create` / `status` request still authorizes the same way.
- Anyone who passes the full authorization for that action (Accessible `authorized_action?` plus `downloadable_available_for?`) may enqueue a build when the package is missing or stale, including anonymous actors when the audience is `public`. Unauthorized requests never enqueue. Builds are deduplicated (one in-flight job per recording + action + export_scope + format). `show` and `create` stay rate-limited; `status` may enqueue only when authorized and nothing is in flight (missing or stale, never a failed retry).
- Host API for subscribers: `recording.downloadable_generate!(action:, export_scope:, ...)` and `recording.downloadable_invalidate!(immediate: true)`. Downloadable does not depend on Publishable.
- Fingerprints include action and export scope and are re-checked before serving.
- Immediate invalidation for attachment removal and trash; debounced rebuilds (30–60s) for ordinary content changes once a package exists.
- Per-action rate limits (IP, actor, recording), concurrent build cap, and host `max_zip_bytes`.
- I18n under `recording_studio.downloadable.*`.

### Changed
- Dummy and root GitHub pins: Accessible `v0.14.0`.
- README documents the Accessible action API. Signed storage URLs are described as bearer links until expiry (default 5 minutes).

### Upgrade notes
1. Pin `recording_studio_accessible` to GitHub tag `v0.14.0` (not RubyGems).
2. Copy and run the new Downloadable migration, plus Accessible's `AccessConstraint` / `AccessRule` migrations if you use action audiences:

   ```bash
   bin/rails generate recording_studio_downloadable:migrations
   bin/rails generate recording_studio_accessible:migrations
   bin/rails db:migrate
   ```

3. Configure each download action:

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

   Add `public` to `allowed` only when anonymous downloads should succeed. Domain conditions belong on `downloadable_available_for?`.
4. Actions that are not listed in `action_audiences` and have no `define_action` policy still use `config.auth_roles` (`download: :view`). Move hosts onto `authorized_action?` when you can.
5. Rolling the identity migration back is only safe before you store more than one package per recording (different actions or scopes).

## [0.2.0] - 2026-10-06

### Added
- `source: :manifest` so a host or domain gem can supply the ZIP file list via `#downloadable_manifest`.
- `RecordingStudioDownloadable::DownloadFile.from_blob` and `.from_string` for stored blobs and generated content.
- Generated files take part in the existing fingerprint and package lifecycle: identical manifests reuse a ZIP; changed text or blobs mark it stale.

### Changed
- Dummy and root GitHub pins: Recording Studio `v4.2.2`, Accessible `v0.11.1`, Attachable `v0.7.1`, FlatPack `v0.1.198`. Dummy Accessible role column is a string; Attachable attachments gain `caption`, `credit`, and `alt_text`.

### Upgrade notes
- `source: :attachments` is unchanged. Existing includes keep working with no host edits.
- Opt in to `source: :manifest` only on types that implement `#downloadable_manifest` returning `DownloadFile` objects. Missing methods and invalid entries raise; they do not fall back to attachments.

## [0.1.0] - 2026-10-02

### Added
- Initial V1 of RecordingStudio Downloadable.
- Opt-in `include RecordingStudio::Capabilities::Downloadable.to(source: :attachments, format: :zip)`.
- Direct Attachable file discovery, ZIP generation via Active Job, package persistence, and an authorized download route.
- Authorization maps action `:download` to an Accessible role (default `:view`) the same way Attachable does.

[Unreleased]: https://github.com/bowerbird-app/RecordingStudio_downloadable/compare/v0.5.0...HEAD
[0.5.0]: https://github.com/bowerbird-app/RecordingStudio_downloadable/releases/tag/v0.5.0
[0.4.0]: https://github.com/bowerbird-app/RecordingStudio_downloadable/releases/tag/v0.4.0
[0.3.0]: https://github.com/bowerbird-app/RecordingStudio_downloadable/releases/tag/v0.3.0
[0.2.0]: https://github.com/bowerbird-app/RecordingStudio_downloadable/releases/tag/v0.2.0
[0.1.0]: https://github.com/bowerbird-app/RecordingStudio_downloadable/releases/tag/v0.1.0
