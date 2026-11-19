# Migration Notes

## Current Requirements

- Ruby 3.3 or newer
- Rails 8.1 or newer
- Recording Studio 7.0 (`>= 7.0`, `< 8.0` in the gemspec; dummy GitHub tag `v7.8.0`)
- Accessible dummy tag `v0.58.0`, Attachable dummy tag `v0.34.0`, and Root Switchable dummy tag `v0.17.0`
- Cache dummy tag `v0.8.0` (gemspec `>= 0.5`), Logs dummy tag `v0.9.0` (gemspec `>= 0.8.0`), and Metrics dummy tag `v0.10.0`
- Trashable dummy tag `v1.3.0`, Admin dummy tag `v2.20.0`, API dummy tag `v1.21.2`, Moveable dummy tag `v6.1.0`, and Icons dummy tag `v0.5.0`
- FlatPack tag `v0.2.0`
- Public RubyGems and GitHub access for dependency installation

## Verification

Install both bundles and run the complete gem and dummy app test path:

```bash
bundle install
BUNDLE_GEMFILE=test/dummy/Gemfile bundle install
bundle exec rake test:all
```

Run the dummy app from its directory for browser verification:

```bash
cd test/dummy
bin/dev
```

Use the [FlatPack repository](https://github.com/bowerbird-app/flatpack) and the live FlatPack demo linked from the top-level README for current component documentation.
