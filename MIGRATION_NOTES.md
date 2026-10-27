# Migration Notes

## Current Requirements

- Ruby 3.3 or newer
- Rails 8.1 or newer
- Recording Studio 6.1 (`>= 6.1.0` in the gemspec; dummy GitHub tag `v6.1.0`)
- Accessible dummy tag `v0.22.0` and Root Switchable dummy tag `v0.11.0`
- Cache dummy tag `v0.5.1`, Logs dummy tag `v0.7.0` (gemspec `>= 0.4.1, < 1.0`), and Metrics dummy tag `v0.6.1`. Those three gemspecs still declare `recording_studio ~> 4.2`. The test bundle widens that requirement before `Bundler.setup`.
- FlatPack commit `1fcbafe94f8eb118f0a22182f63f5110fcc97a56` (`0.1.319`)
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
