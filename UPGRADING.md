# Upgrading Recording Studio Downloadable

## 0.16.1

`0.16.1` registers named MCP tools for the download actions. No Downloadable migration. Recording Studio MCP is not a gemspec dependency.

1. Pin `recording_studio_downloadable` to `0.16.1`.
2. Hosts that do not load Recording Studio MCP need no other change.
3. Hosts that mount MCP include one `download_<public name>` tool per recordable that opted into Downloadable, and `register_type` those recordables. `download_press_kit` calls `:downloadable_download` for a Press kit. The tool returns package status (`state`, `ready`, `stale`, `failed`). Fetch the ZIP through the authorized package route. Do not register a Download type, a generic `download` tool, or `capability_action` for this action.
4. OpenAPI descriptions for `:downloadable_download` and `:downloadable_package_status` describe the HTTP call, the JSON fields, and the not-found, download-gate, and rate-limit outcomes. MCP wording is separate.
5. The development dummy pins MCP `v0.45.2` (`>= 0.45`, `< 0.46`), Oauth `v0.26.0` (`~> 0.26`), Site Settings `v0.7.0` (`~> 0.7`), and API `v1.21.3`. MCP `0.45` requires API `>= 1.21.3`. A loaded MCP older than `0.45` does not register these tools.
6. Dummy pins Puma `8.1.2`, Brakeman `8.1.1`, net-ssh `~> 7.3.10`, and Ruby `3.3.14`. Development pins Puma `8.1.2` and Ruby `3.3.14`.

## 0.16.0

`0.16.0` keeps the same gemspec runtime floors. No Downloadable migration.

1. Pin `recording_studio_downloadable` to `0.16.0`.
2. Hosts MUST run the Recording Studio 7.4, 7.5 and 7.7 migrations if they have not.
3. flat_pack 0.2.0 is supported; hosts moving to 0.2 must remove the manual `flat_pack/heroicons` importmap pin and any `flat-pack--icon` controller registration.
4. Development and the dummy pin Recording Studio `v7.8.0` (`~> 7.8`), FlatPack `v0.2.0` (`~> 0.2`), Accessible `v0.58.0` (`~> 0.58`), API `v1.21.2` (`~> 1.21`), Attachable `v0.34.0` (`~> 0.34`), Cache `v0.8.0` (`~> 0.8`), Icons `v0.5.0` (`~> 0.5`), Logs `v0.9.0` (`~> 0.9`), Metrics `v0.10.0` (`~> 0.10`), Moveable `v6.1.0` (`~> 6.1`), and Trashable `v1.3.0` (`~> 1.3`). The dummy also pins Admin `v2.20.0` (`~> 2.20`) and Root Switchable `v0.17.0` (`~> 0.17`).

## 0.15.0

`0.15.0` requires Recording Studio `7.0` or newer, below `8.0`. No Downloadable migration.

1. Pin `recording_studio_downloadable` to `0.15.0` and `recording_studio` to `>= 7.0`, `< 8.0`. Development and the dummy pin tag `v7.0.0`.
2. Raise the other Recording Studio runtime floors and drop upper caps: Accessible `>= 0.44.0`, Attachable `>= 0.28.0`, Cache `>= 0.5`, Logs `>= 0.8.0`, Metrics `>= 0.9.0`.
3. Pin the core 7 ladder used here: Accessible `v0.44.0`, Attachable `v0.28.0`, Cache `v0.6.3`, Logs `v0.8.0`, Metrics `v0.9.0`, Trashable `v0.17.0`, API `v0.24.0`, Moveable `v5.0.0`, Icons `v0.2.1`, Root Switchable `v0.16.0`, Admin `v2.16.0`. FlatPack moves to `v0.1.376` because Attachable `0.28` requires `flat_pack >= 0.1.376`. Section titles from that Flatpack render `fp-type-section`.
4. Create roots with `RecordingStudio.create_root_recording!(recordable, actor:)`. `root_recording_for` returns the existing root or `nil`. A second `create_root_recording!` returns that same root and does not append another event.
5. Set `config.authorize_write` to a callback that returns true or false. Do not set `allow_unauthorized_writes`. A write still needs an actor (`actor:` or `config.actor`).
6. Replace `Recording.recording_studio_trashable_kept_sql` with `Recording.kept`. Trashable `0.17` removed `kept_sql`.
7. Recording Studio `6.9` and `7.0` require `root_recording_id` on `recording_studio_events`. Run `bin/rails generate recording_studio:migrations` and migrate when that column is missing. The dummy already includes that migration.
8. Development and the dummy pin Puma `8.1.0`. The dummy also requires `msgpack` `>= 1.8.7`.

## 0.14.1

`0.14.1` allows Recording Studio below `8.0` in the gemspec. The lower bound stays `>= 6.7.1`. No migration. Development and the dummy stay on core 6.x.

1. Pin `recording_studio_downloadable` to `0.14.1`. Recording Studio stays `>= 6.7.1` and below `8.0`.
2. Hosts already on `6.7.1` or newer, below `7.0`, need no other change. This release does not call core 7 APIs.

## 0.14.0

`0.14.0` makes package status cheap when the host can name a cache key. No migration.

1. Pin `recording_studio_downloadable` to `0.14.0`. Recording Studio stays `>= 6.7.1` and `< 7.0`. `recording_studio_cache` stays `~> 0.5` (Cache `0.6.3` still matches).
2. On a recordable whose ZIP is large, define `downloadable_cache_key(action:, export_scope:)`. Return a value that changes whenever any file in the ZIP changes. Downloadable does not know about your files. It mixes action and export scope into the stored key. Do not return recording id plus `updated_at` unless that actually changes when child files change.
3. Define `downloadable_empty?` on that recordable when the ZIP can be empty. Status, show, and enqueue call it instead of building the file list. If the cache key exists and this method does not, those paths skip the file list and treat the source as non-empty. The build job still fails an empty file list.
4. Packages already built before the hook do not match the new key. The next status poll or download queues one rebuild. Hosts that do not define the hook keep the full file fingerprint, memoized for the request, and those packages stay current.
5. A failed package is not rebuilt by a status poll. Show and the generate POST still retry it. Overlapping polls of a missing or stale package enqueue one job.

## 0.13.2

`0.13.2` moves the download-log association and the recording invalidation callback onto Recording Studio's `extend_model(:recording)` hook. Downloads, logs, and invalidation behave the same. No migration.

1. Pin `recording_studio_downloadable` to `0.13.2`. Recording Studio stays `>= 6.7.1` and `< 7.0`.

## 0.13.1

`0.13.1` requires Recording Studio `>= 6.7.1` and `< 7.0`. No Downloadable migration. `recording_studio_cache` stays `~> 0.5` (Cache `0.6.3` still matches).

1. Pin `recording_studio_downloadable` to `0.13.1` and `recording_studio` to `6.7.1` or newer, below `7.0`. Development and the dummy pin tag `v6.10.0`.
2. Pin FlatPack `v0.1.356`, Accessible `v0.32.0`, Attachable `v0.23.0`, Cache `v0.6.3`, Logs `v0.7.4`, Metrics `v0.8.0`, Trashable `v0.14.0`, Admin `v2.13.0`, API `v0.23.0`, Moveable `v4.1.1`, Icons `v0.2.1`, and Root Switchable `v0.15.0`.
3. Attachable `0.23` needs Recording Studio API `~> 0.23`. Declare the API, Moveable, and Icons git sources. Sibling gemspecs already allow Recording Studio `6.1` or newer, so do not widen their requirements at Bundler setup.
4. Recording Studio `6.9` requires `root_recording_id` on `recording_studio_events`. Run `bin/rails generate recording_studio:migrations` and migrate when the host is on `6.9` or newer. The dummy copies that migration.
5. Trashable `0.14` adds nullable `purge_at` on `recording_studio_recordings`. Install `bin/rails generate recording_studio_trashable:migrations` and migrate when this host uses trash retention.
6. Root Switchable `0.15` still expects Accessible `:view` on a root before the mounted switch page opens it.

## 0.13.0

`0.13.0` requires Recording Studio `6.7.0` or newer. No migration.

1. Pin `recording_studio_downloadable` to `0.13.0` and `recording_studio` to `6.7.0` or newer.
2. If the host is coming from Recording Studio older than `6.5.0`, writes now fail closed. `RecordingStudio.record!` raises `RecordingStudio::AuthorizationError` until `config.authorize_write` is set. A missing actor raises `RecordingStudio::ActorRequired`. Set an authorizer that returns true or false, or set `config.allow_unauthorized_writes = true` to keep the previous open writes.
3. Download stats stay available to anyone who passes `downloadable.view_logs` until you register a check. Register it on core. Downloadable does not add a wrapper.

```ruby
# Host code. Downloadable does not load the Stripe gem and does not know plans.
RecordingStudio.register_gate("downloadable.stats", :plan) do |actor:, recording:, **|
  if RecordingStudioStripe::Billing.for_recording(recording).unlocked?(:download_stats)
    true
  else
    RecordingStudio::GateDecision.deny(redirect_to: "/billing")
  end
end
```

Return `true` to allow, `false` to hide stats the way a missing permission does, or `RecordingStudio::GateDecision.deny(redirect_to:)` to send HTML history screens to that URL. No checks means allow. The first deny wins. A raised error denies without a redirect.

`redirect_to` applies to HTML requests for `download_logs` and `download_logs_rollup`, including the chart and the table. Metrics `download_logs.total` and `download_logs.over_time` stay denied and do not redirect. JSON requests for those screens stay not-found. The filter-options endpoint stays not-found. The history link hides. Admin has no screen redirect, so Downloadable redirects in a before_action on `RecordingStudioAdmin::ScreensController` before Admin turns a hidden screen into not-found. An allowed HTML request can call the check twice. Keep it free of side effects.

Someone who fails `downloadable.view_logs` stays denied even when the gate would allow. A nil recording stays denied and the gate is not called. `register_download_gate` is unchanged. It still pauses the ZIP, not the stats.

## 0.12.0

`0.12.0` exposes download through Recording Studio API. No migration.

1. Pin `recording_studio_downloadable` to `0.12.0`.
2. If the host loads Recording Studio API, pin `recording_studio_api` to `v0.21.4` and `recording_studio_admin` to `v2.13.0`. API `0.21.4` stops shadowing Admin's history filter-fields partial.
3. HTML package `GET` still authorizes, gates, rate-limits, and serves as before.
4. If the host registers a recordable type API, add `capability_actions: %i[downloadable_download downloadable_package_status]` (or the subset you want) on downloadable types. The gem registers the actions. The type list is still default-deny.
5. `:downloadable_download` is POST. It authorizes, honors the download gate and rate limit, then builds or queues the ZIP and returns package status. It does not return a download URL. `:downloadable_package_status` is GET and reads `downloadable_package`. Recording Studio API `required_role` is the global `Api.download_role` (`config.auth_roles` `:download`, default `:view`). A weaker per-type `auth_roles` value is refused by Recording Studio API before the handler runs.
6. Download log metrics on the API now require `downloadable.view_logs` (edit), the same as the Admin history screen.

## 0.11.1

`0.11.1` stops the install generator from appending a Downloadable Stimulus lazy-load line. No migration.

1. Pin `recording_studio_downloadable` to `0.11.1`.
2. Delete this line from `app/javascript/controllers/index.js` if a previous install added it:

```js
lazyLoadControllersFrom("controllers/recording_studio_downloadable", application)
```

Keep `lazyLoadControllersFrom("controllers", application)` or the host's eager load of `controllers`. The importmap pin `controllers/recording_studio_downloadable` stays. That load resolves `recording-studio-downloadable--package`.

The deleted line scans every `data-controller` on the page. The browser then logs `Failed to autoload controller` for controllers that do not live in this gem.

## 0.11.0

`0.11.0` retitles the admin download history screen, changes its default grouping, and replaces the 0.10 subtree query with Admin 2.12 scoped recordings. No migration.

1. Pin `recording_studio_downloadable` to `0.11.0`.
2. If the host loads Admin, pin `recording_studio_admin` to `v2.12.0` or newer. That requires Recording Studio `>= 6.3.0` and Flatpack `>= 0.1.341`. Downloadable's gemspec still allows Recording Studio `>= 6.1.0`. Admin is not a Downloadable dependency. Hosts that do not load Admin are unchanged.
3. The screen title is Downloads (`recording_studio.downloadable.history.screen_title`). The Downloads section link still reads Download history (`history.title`) and opens the current root's rollup.
4. The screen no longer shows a subtitle. `history.subtitle` is gone. New keys, each with an English default: `history.who` ("Who"), `history.kind` ("Kind"), `history.within_all` ("All items"), and `history.table_title` ("Download log"). The table heading on both screens is Download log.
5. Group by defaults to week. Day, week, and month stay available. A URL that already sets `group_by` is unchanged. Auth stays `:"downloadable.view_logs"` on the anchor. `last_4_weeks` is today minus 27 days through today.
6. Drop `scope=subtree`. Admin reserves `scope` for Root Switchable. A leftover `scope=subtree` can switch the current root. Do not send `recording_ids[]`. Do not use `root_recording_id`.

`download_logs?recording_id=` lists that recording only. Period, group by, and Who are its filters. `download_logs_rollup?recording_id=` lists that anchor and kept descendants on the history allowlist. `rollup: true` or a `recordable_type` on the history helper opens the rollup screen. The allowlist defaults to every type that opted in with Downloadable `.to`. Override it before Admin boots:

```ruby
RecordingStudioDownloadable.configuration.history_recordable_types = %w[PressKit Page]
```

`nil` keeps the default. An empty list turns the rollup off, and the query is only the anchor. After a later change, call `RecordingStudioDownloadable::Admin::DownloadLogsRollupScreen.install_scope!`. The rollup draws one within filter per allowlisted type. That list is fixed when the screen registers, so a request cannot hide Page while keeping Press kit. Set the allowlist to the types that should appear.

Kind is one class name. An unknown type is ignored and the allowlist stays in effect. That differs from 0.10, where a list of unknown types emptied the table. Within drills into one item and everything under it. The param key is `item_` plus the underscored type. A descendant count past Admin `max_scoped_recordings` (default 5000) returns 422.

```
/admin/screens/download_logs?recording_id=:id
/admin/screens/download_logs_rollup?recording_id=:id
/admin/screens/download_logs_rollup?recording_id=:id&recordable_type=PressKit
/admin/screens/download_logs_rollup?recording_id=:id&item_press_kit=:child_id
```

```ruby
recording_studio_downloadable_history_link(recording)
recording_studio_downloadable_history_link(
  press_center_recording,
  rollup: true,
  recordable_type: "PressKit"
)
```

`scope:` raises `ArgumentError`. An array `recordable_type` raises. Pass `rollup: true` when the anchor is not downloadable.

## 0.10.0

`0.10.0` added optional subtree download history. `0.11.0` replaces that query. Use the 0.11.0 notes above. The 0.10 behavior was:

1. Pin `recording_studio_downloadable` to `0.10.0`.
2. Keep existing history links. `?recording_id=` still lists that recording only. `recording_studio_downloadable_history_link(recording)` is unchanged.
3. To roll up downloads under a parent (a press center that is not downloadable, with kits below it), link with subtree. Pass your own type names. Downloadable does not know Press Centers or kits.

```ruby
recording_studio_downloadable_history_link(
  press_center_recording,
  scope: :subtree,
  recordable_type: %w[Kit Images]
)
```

```
/admin/screens/download_logs?recording_id=:press_center_id&scope=subtree&recordable_type[]=Kit&recordable_type[]=Images
```

`downloadable.view_logs` is checked on the press center recording only. Unknown `recordable_type` values are ignored. If none of the types are declared, the table is empty. On the subtree screen, What lists those items by name. Pick one kit to see only its logs. All restores the subtree and still honors `recordable_type` on the URL. Item history stays when and who. Do not send `recording_ids[]`. Do not use `root_recording_id` for this rollup.

## 0.9.0

`0.9.0` requires Recording Studio `>= 6.1.0` and develops against Flatpack `0.1.319`.

1. Pin `recording_studio` to GitHub tag `v6.1.0` (`>= 6.1.0`).
2. Pin `flat_pack` to commit `1fcbafe94f8eb118f0a22182f63f5110fcc97a56` (`0.1.319`, `>= 0.1.315`). Flatpack is not a Downloadable runtime dependency. The host Gemfile supplies it. Keep `view_component` at `>= 4.14, < 5`.
3. Pin Accessible `v0.22.0`, Attachable `v0.22.0`, Trashable `v0.12.0`, Admin `v2.7.0`, and Root Switchable `v0.11.0`. Pin Cache `v0.5.1`, Logs `v0.7.0`, and Metrics `v0.6.1`. Those three gemspecs still declare `recording_studio ~> 4.2`. Widen that requirement before `Bundler.setup` (see `test/support/widen_recording_studio_requirement.rb`).
4. Leave `RecordingStudioDownloadable.configuration.layout` unset to use `RecordingStudio.configuration.layout`, then `recording_studio/default_layout`. Set a layout name, `false`, or a callable invoked as `call(controller:)`. `false` skips the layout and does not fall through.
5. Replace `include RecordingStudio::UsesDefaultLayout` and `layout "recording_studio/default_layout"` with `recording_studio_layout`. Do not hard-code a `recording_studio/` layout name. `bundle exec rake recording_studio:check_layouts` reports those calls.
6. Set page headings with `content_for :title` and `content_for :subtitle`. The default layout renders one `FlatPack::PageTitle`. Remove a second page-level title from the view. Back and close use `flat_pack_page_nav(round: true, style: :default, back_href:, back_tooltip:, anchor_href:, anchor_tooltip:)`. Right-side actions use `register_page_nav` or `recording_studio_page_nav_right`. `FlatPack::Card` no longer accepts `style:`.

No Downloadable migration.

## 0.8.1

`0.8.1` lifts the Logs gemspec ceiling to `< 1.0`. No migration. Pin `recording_studio_logs` to GitHub tag `v0.5.0` as before. Hosts may take any Logs release in `>= 0.4.1, < 1.0`.

## 0.8.0

`0.8.0` registers the existing download log with RecordingStudioLogs. There is no daily summary table.

1. Pin `recording_studio_logs` to GitHub tag `v0.5.0` (allowed range `>= 0.4.1, < 0.6`).
2. Install Logs run tables if the host does not already have them:

```sh
bin/rails generate recording_studio_logs:migrations
```

3. Copy and run the Downloadable migrations:

```sh
bin/rails generate recording_studio_downloadable:migrations
bin/rails db:migrate
```

Those migrations add `root_recording_id` to `recording_studio_downloadable_download_logs`, backfill it from `recording_studio_recordings`, and add a root-and-time index. Existing download rows stay in the same table. The table is not partitioned.

Admin history, Metrics charts, the pre-download gate, and rate limits stay on raw download logs. Do not schedule Logs partition jobs for this table. Logs retention never drops a log with no aggregations. The gem's own pruner still deletes.
