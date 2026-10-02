# Dummy App

This Rails app exists to validate the Recording Studio addon template in a real host application.

## What It Covers

- Devise authentication with a seeded admin user
- `Current.actor` wiring for Recording Studio events
- Root workspace plus seeded folder and page recordables
- Recording Studio helpers plus a dummy-only FlatPack left sidebar layout, assets, and Tailwind source scanning
- Mounted `RecordingStudio::Engine` route behavior inside a host app
- Dummy-only `/docs/*` pages for gem-specific onboarding

## Quick Start

```bash
cd test/dummy
bundle install
bin/rails db:setup
bin/dev
```

Run the commands above from the dummy app directory, not the repository root.

Then open the app and sign in with:

- Email: `admin@admin.com`
- Password: `Password`

## Useful Routes

- `/` - dummy app home page and template guidance
- `/recording_studio` - redirects to `/` while the mounted Recording Studio engine stays available under that prefix for non-root routes
- `/users/sign_in` - Devise sign-in page
- `/docs/install`, `/docs/config`, `/docs/recordable_types`, `/docs/recordings_tree`, `/docs/gem_views`, `/docs/methods` - dummy-only starter pages
- `/pages` - dummy table of Page recordables; `/pages/new` creates a page then opens Attachable upload
- Download on home or Pages `POST`s ZIP generation. Stimulus polls `/recording_studio_downloadable/recordings/:id/package/status` until `ready`, then starts the authorized GET so the ZIP downloads without a manual refresh.
- `/up` - Rails health check

## Active Storage / Cloudflare R2

Uploads use Disk (`local`) unless you point the dummy at R2. Set these in the environment (never commit secrets):

```bash
export DUMMY_ACTIVE_STORAGE_SERVICE=cloudflare_r2   # or amazon
export DUMMY_AWS_ACCESS_KEY_ID=...
export DUMMY_AWS_SECRET_ACCESS_KEY=...
export DUMMY_AWS_REGION=auto
export DUMMY_AWS_BUCKET=attachable-test
# optional: export DUMMY_AWS_ENDPOINT=https://<accountid>.r2.cloudflarestorage.com
```

`config/storage.yml` reads those variables. The default endpoint is the attachable-test R2 account. Restart `bin/rails server` after changing env. Bucket CORS is configured on R2 (including the ngrok host), not in this repo.

## Why This App Exists

Use this app to verify the generated addon experience before renaming the gem or copying patterns into another host app. If a layout, route, asset source, or Recording Studio initializer change breaks here, the template likely needs adjustment before reuse.

Authenticated pages use `layouts/flat_pack_sidebar` (`FlatPack::SidebarLayout`) so the left nav and main pane scroll independently. Devise sign-in keeps `layouts/application`. Replace dummy docs page content so it matches the gem's actual concepts.

The home page in `app/views/home/index.html.erb` should stay a minimal demo surface for the gem's core feature. Do not turn it into a wall of documentation; the dummy docs pages exist so deeper explanations can live in focused sections.
