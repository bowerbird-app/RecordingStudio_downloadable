# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- Dummy and root GitHub pins: Recording Studio `v4.2.2`, Accessible `v0.11.0`, Attachable `v0.7.0`, FlatPack `v0.1.198`. Dummy Accessible role column is a string; Attachable attachments gain `caption`, `credit`, and `alt_text`.

## [0.1.0] - 2026-10-02

### Added
- Initial V1 of RecordingStudio Downloadable.
- Opt-in `include RecordingStudio::Capabilities::Downloadable.to(source: :attachments, format: :zip)`.
- Direct Attachable file discovery, ZIP generation via Active Job, package persistence, and an authorized download route.
- Authorization maps action `:download` to an Accessible role (default `:view`) the same way Attachable does.

[Unreleased]: https://github.com/bowerbird-app/RecordingStudio_downloadable/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/bowerbird-app/RecordingStudio_downloadable/releases/tag/v0.1.0
