# TestFlight builds of this fork (Codemagic)

Workflow `nuviotv-testflight` in `codemagic.yaml` builds the NuvioTV scheme from source on a Codemagic Mac, signs it for our team (bundle id `com.adamle.nuviotv`, Top Shelf `com.adamle.nuviotv.topshelf`), and uploads it to TestFlight.

## One-time setup
1. Codemagic: add the repo `alwork-star/NuvioTV` as an app (codemagic.yaml workflow).
2. Codemagic app, Environment variables: group `nuviotv` with `CERTIFICATE_PRIVATE_KEY` (the same signing key the Chorus build uses, marked secret). Optional: `TMDB_API_KEY` (free TMDB account) for TMDB rows and artwork.
3. First run: it registers both bundle ids, then stops in about 2 minutes with "NO APP RECORD".
4. App Store Connect, Apps, +, New App: platform tvOS, any unique name, bundle id `com.adamle.nuviotv`, any SKU.
5. Run again: full build (about 20 to 35 minutes), upload to TestFlight.
6. Apple TV (tvOS 26 or later; the project's deployment target is 26.0): install TestFlight and the build.
7. Scheduled build every 60 days (TestFlight builds expire after 90).

## First-build choices
- App Group removed from both targets (App Groups cannot be created through the API). Top Shelf is empty until `group.com.adamle.nuviotv` is registered, assigned to both bundle ids, and `KEEP_APP_GROUP=1` is set in the group.
- `ITSAppUsesNonExemptEncryption = NO` is added, so TestFlight does not ask about export compliance on every build.

## Upstream updates
Sync this fork from youngchris29-art/NuvioTV (and its NuvioMobile submodule pointer), then run the workflow.
