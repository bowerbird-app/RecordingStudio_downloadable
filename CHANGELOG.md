# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0/).

## [Unreleased]

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

[Unreleased]: https://github.com/bowerbird-app/RecordingStudio_downloadable/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/bowerbird-app/RecordingStudio_downloadable/releases/tag/v0.3.0
[0.2.0]: https://github.com/bowerbird-app/RecordingStudio_downloadable/releases/tag/v0.2.0
[0.1.0]: https://github.com/bowerbird-app/RecordingStudio_downloadable/releases/tag/v0.1.0
