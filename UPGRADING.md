# Upgrading Recording Studio Downloadable

## 0.12.0

`0.12.0` exposes download through Recording Studio API. No migration.

1. Pin `recording_studio_downloadable` to `0.12.0`.
2. If the host loads Recording Studio API, pin `recording_studio_api` to `v0.21.4` and `recording_studio_admin` to `v2.13.0`. API `0.21.4` stops shadowing Admin's history filter-fields partial.
3. HTML package `GET` still authorizes, gates, rate-limits, and serves as before.
4. If the host registers a recordable type API, add `capability_actions: %i[downloadable_download downloadable_package_status]` (or the subset you want) on downloadable types. The gem registers the actions. The type list is still default-deny.
5. `:downloadable_download` is POST. It authorizes, honors the download gate and rate limit, then builds or queues the ZIP and returns package status. It does not return a download URL. `:downloadable_package_status` is GET and reads `downloadable_package`. Recording Studio API `required_role` is the global `Api.download_role` (`config.auth_roles` `:download`, default `:view`). A weaker per-type `auth_roles` value is refused by Recording Studio API before the handler runs.
6. Download log metrics on the API now require `downloadable.view_logs` (edit), the same as the Admin history screen.

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
