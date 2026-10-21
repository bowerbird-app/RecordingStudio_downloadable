# Upgrading Recording Studio Downloadable

## 0.8.0

`0.8.0` registers the existing download log with RecordingStudioLogs. Summaries stay off.

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

Those migrations add `root_recording_id` to `recording_studio_downloadable_download_logs`, backfill it from `recording_studio_recordings`, add a root-and-time index, and create `recording_studio_downloadable_download_day_summaries`. Existing download rows stay in the same table. The table is not partitioned.

4. Leave `config.logs_summaries_enabled` false. Admin history, Metrics charts, the pre-download gate, and rate limits stay on raw download logs.

5. Optional. After you compare a rebuilt UTC range, turn the flag on and rebuild:

```sh
FROM=2026-10-01 TO=2026-10-20 bin/rails recording_studio_downloadable:download_logs:backfill_summaries
```

Do not schedule Logs partition jobs for this table.
