# Reproducible builds (recommendations)

## Current state

- CI pins Flutter **3.41.6** in `.github/workflows/public-verification.yml`.
- `.fvmrc` records the same version for local FVM users.
- `pubspec.lock` is **gitignored** today, so transitive Pub versions float within
  the ranges in `pubspec.yaml` on every `flutter pub get`.
- `intl` is pinned to `0.20.2` in `pubspec.yaml`, which matches Flutter 3.41.6's
  `flutter_localizations`. Newer Flutter stable may require `intl ^0.20.3` and
  will fail `pub get` until dependencies are upgraded together.

## Recommended next steps (maintainer decision)

1. Generate `pubspec.lock` with Flutter 3.41.6, stop ignoring it for this **app**
   repository, and commit it so CI and contributors resolve the same graph.
2. Keep `.fvmrc` / CI Flutter version in lockstep when upgrading.
3. Prefer stable (non-beta) `flutter_secure_storage` when a stable release covers
   required platforms.
4. After committing the lockfile, enable Dependabot `pub` PRs (already configured)
   and require CI green before merge.

Do not commit a lockfile produced on a different Flutter major/minor than CI.
