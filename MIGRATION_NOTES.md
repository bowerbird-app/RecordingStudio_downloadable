# Migration Notes

## Current Requirements

- Ruby 3.3 or newer
- Rails 8.1 or newer
- Recording Studio 7.0 (`>= 7.0`, `< 8.0` in the gemspec; dummy GitHub tag `v7.0.0`)
- Accessible dummy tag `v0.44.0`, Attachable dummy tag `v0.28.0`, and Root Switchable dummy tag `v0.16.0`
- Cache dummy tag `v0.6.3` (gemspec `>= 0.5`), Logs dummy tag `v0.8.0` (gemspec `>= 0.8.0`), and Metrics dummy tag `v0.9.0`
- Trashable dummy tag `v0.17.0`, Admin dummy tag `v2.16.0`, API dummy tag `v0.24.0`, Moveable dummy tag `v5.0.0`, and Icons dummy tag `v0.2.1`
- FlatPack tag `v0.1.376`
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
