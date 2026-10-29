# Upgrading Recording Studio Downloadable

## 0.9.0

`0.9.0` requires Recording Studio `>= 6.1.0` and develops against Flatpack `0.1.319`.

1. Pin `recording_studio` to GitHub tag `v6.1.0` (`>= 6.1.0`).
2. Pin `flat_pack` to commit `1fcbafe94f8eb118f0a22182f63f5110fcc97a56` (`0.1.319`, `>= 0.1.315`). Flatpack is not a Downloadable runtime dependency. The host Gemfile supplies it. Keep `view_component` at `>= 4.14, < 5`.
3. Pin Accessible `v0.22.0`, Attachable `v0.22.0`, Trashable `v0.12.0`, Admin `v2.7.0`, and Root Switchable `v0.11.0`. Pin Cache `v0.5.1`, Logs `v0.7.0`, and Metrics `v0.6.1`. Those three gemspecs still declare `recording_studio ~> 4.2`. Widen that requirement before `Bundler.setup` (see `test/support/widen_recording_studio_requirement.rb`).
4. Leave `RecordingStudioDownloadable.configuration.layout` unset to use `RecordingStudio.configuration.layout`, then `recording_studio/default_layout`. Set a layout name, `false`, or a callable invoked as `call(controller:)`. `false` skips the layout and does not fall through.
5. Replace `include RecordingStudio::UsesDefaultLayout` and `layout "recording_studio/default_layout"` with `recording_studio_layout`. Do not hard-code a `recording_studio/` layout name. `bundle exec rake recording_studio:check_layouts` reports those calls.
6. Set page headings with `content_for :title` and `content_for :subtitle`. The default layout renders one `FlatPack::PageTitle`. Remove a second page-level title from the view. Back and close use `flat_pack_page_nav(round: true, style: :default, back_href:, back_tooltip:, anchor_href:, anchor_tooltip:)`. Right-side actions use `register_page_nav` or `recording_studio_page_nav_right`. `FlatPack::Card` no longer accepts `style:`.

No Downloadable migration.

## 0.8.0

`0.8.0` registers the existing download log with RecordingStudioLogs. There is no daily summary table.

1. Pin `recording_studio_logs` to GitHub tag `v0.5.0` (allowed range `>= 0.4.1, < 1.0`).
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
