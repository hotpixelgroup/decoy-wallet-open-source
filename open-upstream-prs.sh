#!/usr/bin/env bash
# Opens the five hardening PRs and the proposal issue on
# decoywalletapp/decoy-wallet-open-source from your fork, with your own
# GitHub login. Safe to re-run: PRs/issue that already exist are reused, and
# every body is (re)written with the real #numbers at the end.
#
# Needs: GitHub CLI (brew install gh), logged in as hotpixelgroup (gh auth login).
set -euo pipefail

UP="decoywalletapp/decoy-wallet-open-source"
FORK="hotpixelgroup/decoy-wallet-open-source"
FORK_OWNER="hotpixelgroup"
UPSTREAM_MAIN="fdf35a010b1202051b158e5c0ba454ace87adcb6"
ISSUE_TITLE='Proposal: contributor templates, Dependabot, gitleaks config and an agent guide'

command -v gh >/dev/null || { echo "GitHub CLI not found. Install it: brew install gh"; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "Not logged in. Run: gh auth login"; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# --- Pre-checks -------------------------------------------------------------
main_now="$(git ls-remote "https://github.com/$UP" refs/heads/main | cut -f1)"
if [ "$main_now" != "$UPSTREAM_MAIN" ]; then
  echo "Stop: upstream main is $main_now, expected $UPSTREAM_MAIN."
  echo "The branches were cut from $UPSTREAM_MAIN; rebase them before opening PRs."
  exit 1
fi
check_head() {  # branch expected-sha
  local now; now="$(git ls-remote "https://github.com/$FORK" "refs/heads/$1" | cut -f1)"
  if [ "$now" != "$2" ]; then echo "Stop: $FORK $1 is '$now', expected $2."; exit 1; fi
}
check_head pr/1-seed-route-handoff       ad8bd251741b4ad642abd8d4f2728d49463b1b25
check_head pr/2-ci-hardening             24cd27945da02e00861d3e59b2f941b1bd51aad2
check_head pr/3-seed-capture-protection  f8a77c7fe2ead41c212043238f1bab45200a2676
check_head pr/4-lockfile-intl            233659e362632c0ecc4953ddedba80573eed4cf2
check_head pr/5-security-docs            4e5ab5bd818ad735ded780017cbe453b6ab53cf7
echo "Pre-checks passed: upstream main and all five fork branches are as expected."

# --- Bodies (placeholders are replaced with real numbers at the end) --------
cat > "$WORK/pr1.md" <<'DECOY_BODY_EOF'
Part of a five-PR hardening series: {PR1} seed route fix · {PR2} CI · {PR3} capture protection (stacked on this PR) · {PR4} lockfile · {PR5} docs. Proposed contributor/governance files are in {ISSUE}.

## Summary
The generated decoy mnemonic travels between the generate, show and verify screens as a go_router query parameter. On web, that puts it in the URL and browser history. Deep linking is enabled (`decoywalletapp://`, `flutter_deeplinking_enabled`, `FlutterDeepLinkingEnabled`), so a crafted link such as `…/showDecoySeedPhrase?mnemonic=…` can also make the app show attacker-chosen words as the user's decoy seed.

## Changes
- **`SeedHandoff`** (new): an in-memory hand-off keyed by decoy id. The show and verify route builders in `nav.dart` read the mnemonic from it and ignore any `mnemonic` query parameter.
- **Missing seed:** if no seed is pending for the decoy id (cold deep link, already verified), the screen redirects to generation instead of dereferencing null.
- **Lifetime:** the pending seed is dropped after verification, when generation is re-entered, on sign-out or account switch (`AppUnlockState.bindUser`), and when the duress PIN opens decoy mode (`beginDecoy`). Locking keeps it, so unlocking returns to the seed screen.
- **Copies:** the generate page drops its own copies once it has handed the seed over.
- **Verify-screen crash (separate commit):** the page's first frame threw `Null check operator used on a null value` on every visit, because the answer buttons used `options.elementAtOrNull(i)!` before the quiz loaded. This predates the hand-off change; the fix shows an empty label until the quiz loads.

## Tests
- **`test/seed_route_behaviour_test.dart`** drives the production generate/show/verify routes from `createRouter` and checks:
  - generating a seed keeps the words out of the router location, out of `extra`, and out of every route update sent to the platform;
  - `?mnemonic=` deep links to show and verify are ignored and redirect;
  - a deep link can't swap in words or show another decoy's seed;
  - verification opens without a build error;
  - sign-out, account switch and the duress PIN drop the seed, and locking keeps it.
- **`test/seed_route_privacy_test.dart`:** a source-level lint over navigation, Uri, launch, share, clipboard and log calls.
- **Checked against real leaks:** each behaviour test goes red for the leak it guards (reading `?mnemonic=` in the show route, passing the seed under a renamed query key, passing it as `extra`).

## Testing (Linux, Flutter 3.41.6)
```
flutter analyze --no-fatal-infos   # 74 issues, same set as main
flutter test                       # 1236 passed, 18 skipped, 3 failed
```
The 3 failures are the existing English home goldens. They fail identically on `main` under Linux; {PR2} addresses them.

## Risk
Low. Dart only, no new dependency. The seed screens use `PopScope(canPop: false)`, so there are no back-navigation paths to break.

## Revert
Revert the three commits.
DECOY_BODY_EOF
cat > "$WORK/pr2.md" <<'DECOY_BODY_EOF'
Part of a five-PR hardening series ({PR1}–{PR5}); independent of the others.

## Changes
- **Pinned actions:** every action is pinned to a full commit SHA, with the version as a comment. Each SHA was checked against its tag with `git ls-remote`: checkout v4.2.2, setup-java v4.7.1, flutter-action v2.19.0, upload-artifact v4.6.2, attest-build-provenance v2.4.0.
- **No expressions in `run:`:** build metadata is passed through `env:` instead of `${{ }}` inside `run:`.
- **Permissions:** `id-token`/`attestations: write` are scoped to the job; the workflow default is `contents: read`.
- **Checkout:** `persist-credentials: false`; no later step uses git credentials.
- **Concurrency:** superseded `pull_request` runs are cancelled. Pushes to `main` and tags always finish, so every commit keeps its debug APK and provenance attestation.
- **Goldens:** in `test/localized_home_page_test.dart`, the three English home goldens are compared on macOS only, or anywhere with `DECOY_RUN_GOLDENS=1`.
  - On Linux they fail by 1.98%, 1.35% and 0.61% of pixels, so the ubuntu runner could never pass `flutter test`.
  - The isolated diff is only anti-aliased glyph edges; layout and colours match. The images were captured on macOS (the test's capture helper writes to `/private/tmp`).
  - Elsewhere these tests still run their layout checks and are reported as skipped. The goldens themselves and the other 17 languages are unchanged.

## Testing
```
actionlint                                  # clean
zizmor --offline .github/workflows          # no findings
flutter test                                # 1219 passed, 21 skipped, 0 failed (Linux)
DECOY_RUN_GOLDENS=1 flutter test test/localized_home_page_test.dart   # same 3 pixel diffs (comparison intact)
```
This workflow, combined with the rest of the series, ran green on GitHub Actions: https://github.com/hotpixelgroup/decoy-wallet-open-source/actions/runs/42327665446

## Risk
Low.
- **Trade-off:** Linux CI no longer catches pixel-level changes to the English home screen. A macOS run (locally, or a future macOS job) still does.
- **Node 20 warning:** the pinned actions are the same major versions `main` already used. GitHub now warns that they target Node 20 and runs them on Node 24. Moving to newer majors is a separate follow-up.
DECOY_BODY_EOF
cat > "$WORK/pr3.md" <<'DECOY_BODY_EOF'
**Stacked on {PR1}, and draft until on-device QA is done.** This branch contains {PR1}'s three commits; review only the last commit, `feat(seed): request OS capture protection on seed screens`. Merge after {PR1}.

## Changes
- **Android (`MainActivity.kt`):** a `decoy_wallet/secure_screen` method channel sets and clears `FLAG_SECURE` while the show and verify seed screens are visible. That blocks screenshots, screen recording and casting, and blanks the recents thumbnail.
- **iOS (`AppDelegate.swift`):** an opaque overlay on `willResignActive` (app-switcher snapshot) and while `UIScreen.isCaptured` (recording, AirPlay, mirroring). iOS does not let apps block or detect screenshots here, and the code says so.
- **`SecureScreen` (Dart):** reference-counted enable/disable called from the show and verify screens, so stacked seed screens don't clear protection early. Platform errors are swallowed, so protection never breaks the seed flow. No new dependency.

## Testing
```
flutter analyze --no-fatal-infos   # same set as main
flutter test                       # 1239 passed, 18 skipped, 3 failed (same goldens as main; see {PR2})
flutter build apk --debug          # OK (JDK 17, platform 36, build-tools 36.0.0, NDK 28.2.13676358)
```
- **APK contents:** the built APK's `com.decoywalletapp.app.MainActivity` contains the channel name, `Window.addFlags`/`clearFlags` with `0x2000` (`FLAG_SECURE`) and `runOnUiThread`.
- **iOS:** not compiled yet (needs macOS/Xcode).
- **Devices:** neither platform has been run on one yet.

## On-device QA before merge
**Android** (physical device, Android 12+):
1. Generate a seed. On the show screen, take a screenshot: it must be refused.
2. Recents: the app card is blank.
3. Screen recording and casting show black for the seed screen.
4. Continue to verify: still protected. Answer wrongly: back on show, same words, still protected.
5. Answer correctly, reaching System Values: a screenshot now succeeds (flag cleared).
6. On show, lock and unlock the phone, enter the app PIN: back on show with the same words, still protected.
7. Split screen on show: no crash, still protected.
8. `adb shell am start -a android.intent.action.VIEW -d "decoywalletapp://decoywalletapp.com/showDecoySeedPhrase?mnemonic=abandon%20abandon%20abandon%20abandon%20abandon%20abandon%20abandon%20abandon%20abandon%20abandon%20abandon%20about&decoyId=x"`: redirects to Generate, and "abandon" never appears. Repeat with `/seedPhraseVerification`.

**iOS** (physical device, iOS 17 or 18):
1. On show, open the app switcher: the card is the solid dark overlay. Return: the overlay is gone.
2. Screen recording or Screen Mirroring while on show: the overlay is shown throughout, and removed when capture stops.
3. Take a screenshot: it captures the words (documented platform limit).
4. Pull down Notification Center on show and dismiss it: the overlay appears and clears.
5. After verification (System Values), app switcher and recording show real content.
6. The deep link from Android step 8, opened via Safari or Notes: redirects to Generate with no injected words.
7. The contact picker still works after visiting seed screens, with no stray overlay.

## Risk
Medium until device QA is done. The native code is small and isolated behind one channel; a failure falls back to no protection rather than a crash.
DECOY_BODY_EOF
cat > "$WORK/pr4.md" <<'DECOY_BODY_EOF'
Part of a five-PR hardening series ({PR1}–{PR5}); independent of the others.

## Changes
- **`intl` constraint:** `intl: 0.20.2` → `^0.20.2` in the app and in the vendored `cartesian_chart_library_syxakz`. `flutter_localizations` pins `intl` per SDK: 3.41.6 still resolves 0.20.2, and 3.47.9 (which needs `^0.20.3`) resolves 0.20.3 without overrides.
- **Committed lock:** `pubspec.lock`, generated with Flutter 3.41.6 (192 hosted packages; none match an advisory in OSV's Pub data). CI runs `flutter pub get --enforce-lockfile`, so it fails instead of silently building a different graph. Path packages under `dependencies/` keep their locks local.
- **Toolchain files:** `.fvmrc` records 3.41.6; `pubspec_overrides.yaml` and the FVM SDK checkout are ignored.
- **`docs/REPRODUCIBLE_BUILDS.md`:** the lock policy, a note that Codemagic still runs plain `flutter pub get`, and why `flutter_secure_storage` stays on `10.0.0-beta.4` for now.

## Testing
```
flutter pub get --enforce-lockfile   # 3.41.6: OK, no lock changes
flutter pub get                      # 3.47.9: resolves, intl 0.20.3 (5 deps change)
flutter pub get --enforce-lockfile   # 3.47.9: fails as expected (lock is for 3.41.6)
flutter analyze --no-fatal-infos     # same set as main
flutter test                         # 1219 passed, 18 skipped, 3 failed (same as main)
```

## Risk
Low technically. It is a policy change: the lock must be regenerated with the pinned SDK whenever `pubspec.yaml` changes.
DECOY_BODY_EOF
cat > "$WORK/pr5.md" <<'DECOY_BODY_EOF'
Part of a five-PR hardening series. **Merge last:** the wallet notes describe the seed hand-off ({PR1}), capture protection ({PR3}) and the pinned toolchain ({PR4}).

## Changes
- **`SECURITY.md`:**
  - Reporting stays repository-neutral: the private reporting form, else `support@decoywalletapp.com`. Reports are asked for affected paths and seed impact.
  - Scope, in and out.
  - Wallet notes list exactly what arming a decoy sends (id, derivation path, xpub, zpub and type, derived receive addresses, source type, monitoring flag), matching `CommitDecoyCall` and `docs/DECOY_SEED_ENTROPY.md`.
  - The in-memory seed hand-off and the capture protection, including that iOS cannot block screenshots.
- **`README.md`:** status, local verify commands, license pointers.
- **`CONTRIBUTING.md`:** toolchain, backend helper tests, pull request expectations. Keeps `main`'s list of what must not be added.
- **`docs/BACKEND_HELPERS.md`:** what `backend/` holds and which scripts are safe to run during a review.

## Risk
Docs only.
DECOY_BODY_EOF
cat > "$WORK/issue.md" <<'DECOY_BODY_EOF'
Alongside the hardening PRs ({PR1}, {PR2}, {PR3}, {PR4}, {PR5}), I prepared some contributor and governance files. I held them back because they set project policy, which is your call. Please say which, if any, you would like as a PR. They are on `hotpixelgroup/decoy-wallet-open-source`, branch `audit/oss-hardening-2026-11-04`.

| File | What it does | Notes |
|------|--------------|-------|
| `.github/ISSUE_TEMPLATE/` (bug, feature, `config.yml`) | Issue templates; the chooser links security reports to `SECURITY.md` | Keeps blank issues enabled |
| `.github/PULL_REQUEST_TEMPLATE.md` | Asks for summary, commands run, risk level, a short security checklist and a revert plan | |
| `CODE_OF_CONDUCT.md` | Contributor Covenant 2.1 | Enforcement contact set to `support@decoywalletapp.com`; change if you prefer another |
| `.github/dependabot.yml` | Weekly updates for GitHub Actions, pub and Gradle | With 109 exact pins in `pubspec.yaml` and a pinned SDK, pub updates would need grouping/ignores to avoid noise |
| `.gitleaks.toml` | Extends gitleaks defaults; only two narrow false-positive exceptions (pod checksums in `ios/Podfile.lock`, `ff_*` storage key names) | Full history scans clean; planted service-role JWTs are caught everywhere, including `*.example` files. Not wired into CI yet |
| `.editorconfig`, `.gitattributes` | LF line endings; 2-space indentation (4 for Kotlin/Java/Gradle) | `assets/fonts/international/Heebo-OFL.txt` is CRLF in the index and would be renormalized |
| `AGENTS.md`, `CLAUDE.md`, `backend/AGENTS.md` | Rules for AI coding agents: toolchain, wallet security invariants, never-touch list, definition of done | Only useful if you accept agent-written contributions |

No CODEOWNERS is proposed; code owners are yours to name.
DECOY_BODY_EOF

# --- Create (or reuse) ------------------------------------------------------
find_pr() {  # branch -> number of an open PR from the fork branch, if any
  gh pr list --repo "$UP" --state open --limit 100 \
    --json number,headRefName,headRepositoryOwner \
    --jq ".[] | select(.headRepositoryOwner.login==\"$FORK_OWNER\" and .headRefName==\"$1\") | .number" | head -n1
}
open_pr() {  # key branch title draft(yes|no) -> prints number
  local n; n="$(find_pr "$2")"
  if [ -n "$n" ]; then echo "  reusing #$n for $2" >&2; echo "$n"; return; fi
  local url
  if [ "$4" = yes ]; then
    url="$(gh pr create --repo "$UP" --base main --head "$FORK_OWNER:$2" --title "$3" --body-file "$WORK/$1.md" --draft)"
  else
    url="$(gh pr create --repo "$UP" --base main --head "$FORK_OWNER:$2" --title "$3" --body-file "$WORK/$1.md")"
  fi
  echo "  opened $url" >&2
  echo "${url##*/}"
}
N1="$(open_pr pr1 pr/1-seed-route-handoff 'fix(seed): keep the decoy mnemonic out of router params and URLs' no)"
N2="$(open_pr pr2 pr/2-ci-hardening 'ci: pin actions, scope permissions, cancel only PR runs; compare goldens on macOS' no)"
N3="$(open_pr pr3 pr/3-seed-capture-protection 'feat(seed): request OS capture protection on seed screens' yes)"
N4="$(open_pr pr4 pr/4-lockfile-intl 'build: commit pubspec.lock, enforce it in CI, allow intl ^0.20.2' no)"
N5="$(open_pr pr5 pr/5-security-docs 'docs: security policy, verify steps and backend helper notes' no)"

NI="$(gh issue list --repo "$UP" --state open --limit 100 --json number,title \
  --jq ".[] | select(.title==\"$ISSUE_TITLE\") | .number" | head -n1)"
if [ -n "$NI" ]; then
  echo "  reusing issue #$NI" >&2
else
  issue_url="$(gh issue create --repo "$UP" --title "$ISSUE_TITLE" --body-file "$WORK/issue.md")"
  echo "  opened $issue_url" >&2
  NI="${issue_url##*/}"
fi

# --- Fill in the real numbers -------------------------------------------------
fill() {
  sed -e "s/{PR1}/#$N1/g" -e "s/{PR2}/#$N2/g" -e "s/{PR3}/#$N3/g" \
      -e "s/{PR4}/#$N4/g" -e "s/{PR5}/#$N5/g" -e "s/{ISSUE}/#$NI/g" "$1" > "$1.filled"
  if grep -q '{PR[1-5]}\|{ISSUE}' "$1.filled"; then echo "Stop: placeholder left in $1"; exit 1; fi
}
for k in 1 2 3 4 5; do
  fill "$WORK/pr$k.md"
  eval "num=\$N$k"
  gh pr edit "$num" --repo "$UP" --body-file "$WORK/pr$k.md.filled" >/dev/null
done
fill "$WORK/issue.md"
gh issue edit "$NI" --repo "$UP" --body-file "$WORK/issue.md.filled" >/dev/null

echo
echo "Done:"
echo "  PR1 https://github.com/$UP/pull/$N1  (seed route fix)"
echo "  PR2 https://github.com/$UP/pull/$N2  (CI)"
echo "  PR3 https://github.com/$UP/pull/$N3  (capture protection, draft)"
echo "  PR4 https://github.com/$UP/pull/$N4  (lockfile)"
echo "  PR5 https://github.com/$UP/pull/$N5  (docs, merge last)"
echo "  Issue https://github.com/$UP/issues/$NI"
