# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0/).

## [Unreleased]

## [0.14.0] - 2026-11-14

### Added

- Optional `downloadable_cache_key(action:, export_scope:)` on the recordable. The value must change whenever any file in the ZIP changes. Downloadable mixes in action and export scope and stores the result on the package. `ready?`, `stale?`, status, and show compare that stored key and do not build the file manifest. `GeneratePackageJob` is the only path that collects files. It reads the key before the file list and again after the zip is built. If the key changed during the build, the package stays pending and another build is queued.
- Optional `downloadable_empty?` on the recordable so status, show, and enqueue can skip the file list. The dummy press kit defines both hooks. Workspace stays on the full fingerprint.

### Changed

- Status enqueues a build only when the package is missing or stale and no build is already pending or processing. The claim is a locked conditional update, so overlapping polls enqueue one job. A failed package is not retried by polling.
- Without the cache key hook, status still uses the full file fingerprint. That work is memoized for the request. The default is not recording id plus `updated_at`.
- Show serves a ready archive when the stored key matches. It does not rebuild the manifest to prove the bytes.

### Upgrade notes

- Bump to `0.14.0`. No migration. Recording Studio stays `>= 6.7.1`, `< 7.0`.
- To make status cheap, define `downloadable_cache_key` and, when the ZIP can be empty, `downloadable_empty?` on the recordable. See [UPGRADING.md](UPGRADING.md).
- Packages built before the hook do not match the new key. The next status poll or download queues one rebuild. Hosts with no hook keep the file fingerprint and do not rebuild for this change.

## [0.13.2] - 2026-11-14

### Changed

- Recording's download-log association and invalidation `after_commit` register once through `RecordingStudio.configuration.hooks.extend_model(:recording)`. Core applies that extension when the Recording class is loaded or reloaded. The `:downloadable` capability registers from the engine only.

### Upgrade notes

- Bump to `0.13.2`. No migration. No host changes. Recording Studio stays `>= 6.7.1`, `< 7.0`. See [UPGRADING.md](UPGRADING.md).

## [0.13.1] - 2026-11-14

### Changed

- Require `recording_studio` `>= 6.7.1`, `< 7.0`. The open lower bound is the reload fix in Recording Studio `6.7.1`. Development and the dummy pin tag `v6.10.0`.
- Development and dummy Gemfiles pin the current Recording Studio ladder by GitHub release tag: FlatPack `v0.1.356`, Accessible `v0.32.0`, Attachable `v0.23.0`, Cache `v0.6.3`, Logs `v0.7.4`, Metrics `v0.8.0`, Trashable `v0.14.0`, API `v0.23.0`, Moveable `v4.1.1`, Icons `v0.2.1`, and Root Switchable `v0.15.0`. Admin stays `v2.13.0`.
- Attachable `0.23` requires Recording Studio API `~> 0.23`, so the root Gemfile pins API, Moveable, and Icons. The test bundle no longer widens sibling `recording_studio` requirements.
- The dummy app copies Recording Studio `6.9`'s events migration so `recording_studio_events.root_recording_id` is required.

### Upgrade notes

- Bump to `0.13.1`. No Downloadable migration. Requires Recording Studio `>= 6.7.1` and `< 7.0`.
- Hosts on Recording Studio `6.9` or newer run core's events migration. See [UPGRADING.md](UPGRADING.md).

## [0.13.0] - 2026-11-13

### Added

- Optional `downloadable.stats` gate through `RecordingStudio.check_gate`, after `downloadable.view_logs`. Hosts register with `RecordingStudio.register_gate`. No checks means allow. A deny hides the history screens, the history link, and download log metrics. A deny with `redirect_to` redirects HTML requests for `download_logs` and `download_logs_rollup`. Metrics stay denied and do not redirect. A check that raises denies.

### Changed

- Require `recording_studio` `>= 6.7.0`. Development and the dummy pin tag `v6.7.0`.

### Upgrade notes

- Bump to `0.13.0`. No migration. Requires Recording Studio `6.7.0`.
- Hosts coming from core older than `6.5.0` need `config.authorize_write` or `config.allow_unauthorized_writes`. See [UPGRADING.md](UPGRADING.md).

## [0.12.0] - 2026-11-12

### Added

- Recording Studio API capability actions `:downloadable_download` (POST) and `:downloadable_package_status` (GET) on `:downloadable`. Handlers authorize through `context.access_grant.authorize!` and `Authorization.authorize!`, look up the recording in the grant's root, then call `downloadable_generate!` or read `downloadable_package`. `:downloadable_download` builds or queues the ZIP and returns status, not a URL. Recording Studio API `required_role` is the global `Api.download_role` (`config.auth_roles` `:download`, default `:view`). A weaker per-type `auth_roles` value is refused by Recording Studio API first. MCP needs no extra code. Hosts still list the actions on each recordable type API. A colliding action name raises instead of being skipped.

### Changed

- Download log metrics register `api_authorize` with the same Accessible check as Admin history (`downloadable.view_logs`, edit).

### Upgrade notes

- Bump to `0.12.0`. No migration.
- Enable `:downloadable_download` and `:downloadable_package_status` on recordable type APIs that should expose them. See [UPGRADING.md](UPGRADING.md).

## [0.11.1] - 2026-11-12

### Fixed

- The install generator no longer appends `lazyLoadControllersFrom("controllers/recording_studio_downloadable", application)` to the host Stimulus entrypoint. That call scans every `data-controller` and logs `Failed to autoload controller`. The importmap pin stays. `lazyLoadControllersFrom("controllers", application)` already resolves `recording-studio-downloadable--package`.

### Upgrade notes

- Bump to `0.11.1`. No migration.
- Delete `lazyLoadControllersFrom("controllers/recording_studio_downloadable", application)` from `app/javascript/controllers/index.js` if it is there. See [UPGRADING.md](UPGRADING.md).

## [0.11.0] - 2026-11-12

### Changed

- The admin download history screen title is Downloads. The Downloads section link stays Download history.
- Both download history tables are headed Download log (`history.table_title`). Admin's own default heading is Table data.
- That screen no longer shows a subtitle.
- Group by on that screen defaults to week. Day, week, and month stay available.
- Download history uses Admin 2.12 scoped recordings on `download_logs_rollup`. That screen lists the anchor and kept descendants on the history allowlist. The plain `download_logs` screen stays one recording. The 0.10 `scope=subtree` query is replaced. Kind is one `recordable_type`. Within is `item_<underscored_type>=` for one item and everything under it.
- The person filter is labeled Who. Kind and the within filters replace the What select. The What column stays when the rollup is on.
- `history_recordable_types` sets the allowlist. `nil` means every type that opted in with `.to`.
- `download_logs?recording_id=` stays one recording, with period, group by, and Who. Descendants, Kind, and within filters live on `download_logs_rollup`. The history helper opens that screen for `rollup: true` or a `recordable_type`.
- The history line chart uses a straight stroke. A smooth curve was drawn in 0..1 on Admin's 0..max count axis, so a week of 3 downloads looked like a fraction.
- Development and dummy apps pin Admin `v2.12.0`, Recording Studio `v6.3.0`, and Flatpack `v0.1.341`. The gemspec still allows Recording Studio `>= 6.1.0`. Admin stays a host dependency.

### Upgrade notes

- Bump to `0.11.0`. No migration.
- The screen title key is `recording_studio.downloadable.history.screen_title` (English "Downloads"). `history.title` still labels the section link.
- `history.subtitle` is removed. Added `history.who` ("Who"), `history.kind` ("Kind"), `history.within_all` ("All items"), and `history.table_title` ("Download log").
- Replace `?scope=subtree&recordable_type=` links. `recording_studio_downloadable_history_link` takes `rollup:` and one `recordable_type:` string. `scope:` raises. See [UPGRADING.md](UPGRADING.md).

## [0.10.2] - 2026-11-05

### Changed

- Development and dummy lockfiles take Rails `8.1.4.1`, rack `3.2.8`, nokogiri `1.19.7`, loofah `2.25.3`, and rails-html-sanitizer `1.7.2`. Dummy net-ssh stays `7.3.8`.

### Upgrade notes

- Bump to `0.10.2`. No migration. No runtime behavior change.

## [0.10.1] - 2026-11-02

### Changed

- Stop tracking SimpleCov root and dummy `coverage/` output. `.gitignore` already ignored `coverage/`.
- README intro matches the gemspec: Recording Studio `>= 6.1.0`.

### Upgrade notes

- Bump to `0.10.1`. No migration. No runtime behavior change.

## [0.10.0] - 2026-10-29

### Added

- Admin download history can open an authorized **anchor** recording plus its Core descendants (`scope=subtree`). Optional `recordable_type` limits that tree to declared types for host links. The subtree screen has a What filter of concrete items by name. Auth stays `downloadable.view_logs` on the anchor. The anchor does not need to be downloadable.
- `recording_studio_downloadable_history_link` accepts `scope:` and `recordable_type:`. Omit them and the link is unchanged.
- Subtree tables add a What column with the item name.

### Upgrade notes

- Bump to `0.10.0`. No migration.
- Single-recording `?recording_id=` links stay the same. See [UPGRADING.md](UPGRADING.md).

## [0.9.0] - 2026-10-27

### Changed

- Require `recording_studio >= 6.1.0`. Development and dummy Gemfiles pin GitHub tag `v6.1.0` and Flatpack commit `1fcbafe94f8eb118f0a22182f63f5110fcc97a56` (`0.1.319`). Flatpack stays out of this gemspec. `view_component` stays `>= 4.14, < 5` via Flatpack.
- `RecordingStudioDownloadable::Configuration#layout` defaults to `nil`. `nil` uses `RecordingStudio.configuration.layout`, then `recording_studio/default_layout`. The engine controller calls `recording_studio_layout`.
- Dummy pages set `content_for :title` and `content_for :subtitle`. Back uses `flat_pack_page_nav`. The sidebar shell renders one page heading. `FlatPack::Card` calls no longer pass `style:`.
- Accessible pin is `v0.22.0`. Attachable pin is `v0.22.0`. Trashable pin is `v0.12.0`. Admin pin is `v2.7.0`. Root Switchable pin is `v0.11.0`. Cache pin is `v0.5.1`. Logs pin is `v0.7.0`. Metrics pin is `v0.6.1`. Cache, Logs, and Metrics still declare `recording_studio ~> 4.2`, so the test bundle widens that requirement.

### Upgrade notes

- Bump to `0.9.0`. No migration. Hosts on Recording Studio 4 cannot install this version.
- See [UPGRADING.md](UPGRADING.md).

## [0.8.1] - 2026-10-22

### Changed

- Lifted the `recording_studio_logs` gemspec ceiling to `< 1.0` (`>= 0.4.1`, `< 1.0`). CI tested with Logs 0.5.0. No code change.

### Upgrade notes

- Bump to `0.8.1`. No migration. Pin `recording_studio_logs` as before (GitHub tag `v0.5.0` still matches). Hosts may take any Logs release in `>= 0.4.1, < 1.0`.

## [0.8.0] - 2026-10-21

### Added

- `recording_studio_logs` (`>= 0.4.1, < 0.6`). Development and dummy Gemfiles pin GitHub tag `v0.5.0`.
- RecordingStudioLogs registration for the existing download log only (`partition_interval: nil`, `root_column: :root_recording_id`, retention `:indefinite`). No daily summary table.
- `root_recording_id` on `recording_studio_downloadable_download_logs`, backfilled from the recording root. New inserts stamp it. Existing rows stay in the same unpartitioned table.

### Changed

- Lint and Security GitHub Actions use Ruby `3.3` instead of `.ruby-version` (`3.3.6`), so `ubuntu-latest` can install a current 3.3 patch.

### Upgrade notes

- Bump to `0.8.0`. Pin `recording_studio_logs` to GitHub tag `v0.5.0`.
- Run `bin/rails generate recording_studio_logs:migrations` if Logs run tables are not already present, then `recording_studio_downloadable:migrations` and `db:migrate`.
- Do not schedule Logs partition jobs. This log has no aggregations, so Logs retention never drops its rows. The gem's own pruner still deletes.

## [0.7.2] - 2026-10-20

### Changed

- 0.7.2 carries the Metrics 0.5 `{ x:, y: }` chart series change from #23. Download history charts pass `RecordingStudioMetrics::Admin.chart_series` through unchanged; Metrics 0.5.0 already emits `{ x:, y: }` points, so this gem no longer remaps `[date, value]` pairs. GitHub tag `v0.7.1` was published on an earlier commit, so that change ships here.

### Upgrade notes

- Bump to `0.7.2`. No migration.
- The gemspec now depends on `recording_studio_metrics >= 0.5.0`. Pin the GitHub tag `v0.5.0`. History charts expect `{ x:, y: }` points from `chart_series`.

## [0.7.1] - 2026-10-20

### Note

- Main briefly numbered this gem `0.7.1` after #23, but tag `v0.7.1` and its GitHub release already pointed at an earlier commit. Use `0.7.2`.

## [0.7.0] - 2026-10-15

### Added

- `register_download_gate` so a host can pause `PackagesController#show` until its own steps are done. HTML redirects to `continuation_url`. Iframe and XHR requests get `409` with `{ "continuation_url": "..." }`. The autostart flag is cleared. Rate limits, enqueue, and the download log wait until the gate is satisfied. `create` and `status` stay gate-free.
- The download button renders the gate component, and does not mount the poller, while the person is allowed and the gate is unsatisfied.
- The package Stimulus controller sends the top window to `continuation_url` on a `409` from `show`, unless the page cancels `recording-studio-downloadable:download-gate` and keeps the person there (for example to open a modal).
- `recording_studio_downloadable_button` accepts a block. With a `data-downloadable-progress` element inside, the package poller updates that bar from status (`missing`, `pending`, `processing`, `ready`) and writes every status into `[data-downloadable-progress-label]`. It then reveals `data-downloadable-started`. Without the block, the button is unchanged.
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

[Unreleased]: https://github.com/bowerbird-app/RecordingStudio_downloadable/compare/v0.14.0...HEAD
[0.14.0]: https://github.com/bowerbird-app/RecordingStudio_downloadable/compare/v0.13.2...v0.14.0
[0.13.2]: https://github.com/bowerbird-app/RecordingStudio_downloadable/compare/v0.13.1...v0.13.2
[0.13.1]: https://github.com/bowerbird-app/RecordingStudio_downloadable/compare/v0.13.0...v0.13.1
[0.13.0]: https://github.com/bowerbird-app/RecordingStudio_downloadable/compare/v0.12.0...v0.13.0
[0.12.0]: https://github.com/bowerbird-app/RecordingStudio_downloadable/compare/v0.11.0...v0.12.0
[0.11.0]: https://github.com/bowerbird-app/RecordingStudio_downloadable/compare/v0.10.2...v0.11.0
[0.10.2]: https://github.com/bowerbird-app/RecordingStudio_downloadable/compare/v0.10.1...v0.10.2
[0.10.1]: https://github.com/bowerbird-app/RecordingStudio_downloadable/compare/v0.10.0...v0.10.1
[0.10.0]: https://github.com/bowerbird-app/RecordingStudio_downloadable/compare/v0.9.0...v0.10.0
[0.9.0]: https://github.com/bowerbird-app/RecordingStudio_downloadable/compare/v0.8.1...v0.9.0
[0.8.1]: https://github.com/bowerbird-app/RecordingStudio_downloadable/compare/v0.8.0...v0.8.1
[0.8.0]: https://github.com/bowerbird-app/RecordingStudio_downloadable/compare/v0.7.2...v0.8.0
[0.7.2]: https://github.com/bowerbird-app/RecordingStudio_downloadable/releases/tag/v0.7.2
[0.7.1]: https://github.com/bowerbird-app/RecordingStudio_downloadable/releases/tag/v0.7.1
[0.7.0]: https://github.com/bowerbird-app/RecordingStudio_downloadable/releases/tag/v0.7.0
[0.5.0]: https://github.com/bowerbird-app/RecordingStudio_downloadable/releases/tag/v0.5.0
[0.4.0]: https://github.com/bowerbird-app/RecordingStudio_downloadable/releases/tag/v0.4.0
[0.3.0]: https://github.com/bowerbird-app/RecordingStudio_downloadable/releases/tag/v0.3.0
[0.2.0]: https://github.com/bowerbird-app/RecordingStudio_downloadable/releases/tag/v0.2.0
[0.1.0]: https://github.com/bowerbird-app/RecordingStudio_downloadable/releases/tag/v0.1.0
