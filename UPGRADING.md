# Upgrading Recording Studio Downloadable

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
