# Rhythm — Xcode Project Setup

**Date:** 31 July 2026
**Status:** Project structure generated & verified. Full app build still needs
the skeleton wiring finished (see the last section).

The Xcode project is **generated from `ios/Rhythm/project.yml`** using
[XcodeGen](https://github.com/yonaskolb/XcodeGen). `project.yml` is the source of
truth — never hand-edit `Rhythm.xcodeproj`; edit the spec and regenerate.

---

## 1. Prerequisites

- **Xcode 15+** (full Xcode, not just Command Line Tools). If `xcodebuild`
  points at CommandLineTools, switch it:
  ```bash
  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
  ```
- **XcodeGen**:
  ```bash
  brew install xcodegen
  ```

## 2. Generate & open

```bash
cd ios/Rhythm
xcodegen generate
open Rhythm.xcodeproj      # open the .xcodeproj, NOT the folder
```

> The folder still contains a legacy `Package.swift` from before the project
> existed. Open `Rhythm.xcodeproj` explicitly so Xcode doesn't open the folder as
> a Swift package. `Package.swift` is superseded by `project.yml` and can be
> deleted once you're comfortable.

First open resolves Swift Package dependencies (**TCA 1.17.0** and
**RevenueCat 5.x**) — allow a minute for the initial fetch.

## 3. Targets

| Target | Type | Platform | Bundle ID | Notes |
|--------|------|----------|-----------|-------|
| `Rhythm` | App | iOS 17 | `com.rhythm.app` | TCA + RevenueCat; embeds Watch + Widget |
| `RhythmWidgets` | App Extension | iOS 17 | `com.rhythm.app.widgets` | Home/Lock widgets + Live Activity |
| `RhythmWatch` | App | watchOS 10 | `com.rhythm.app.watchkitapp` | Standalone SwiftUI |
| `RhythmTests` | Unit test | iOS 17 | `com.rhythm.app.RhythmTests` | Hosts on `Rhythm`; GentleStreak tests |

**Schemes:** `Rhythm` (build app+widget+watch, runs tests) and `RhythmWatch`.
(Xcode also lists auto-schemes for the SPM packages — `RevenueCatUI`, `Sharing`,
etc. — you can ignore those.)

The **Live Activity** attributes (`FocusSessionAttributes`) are shared between
the app and widget targets via file membership (the standard ActivityKit
pattern), configured in `project.yml`.

## 4. Signing & capabilities

Set your team once, in `project.yml` under `settings.base`:

```yaml
DEVELOPMENT_TEAM: "YOURTEAMID"
```

Then regenerate. Capabilities are pre-wired via entitlements in `Config/`:

- **App Groups** (`group.com.rhythm.app`) — app ⇄ widget ⇄ watch shared data
- **HealthKit** — hydration read/write
- **Push Notifications** (`aps-environment: development`)
- **Sign in with Apple**
- **Live Activities** (`NSSupportsLiveActivities` in Info.plist)

**Family Controls / ManagedSettings** (used loosely by `FocusModeClient`)
requires a **special entitlement Apple must grant**. It's intentionally left out
so signing works out of the box; add it once approved (see the comment in
`Config/Rhythm.entitlements`).

### Renaming the bundle-ID prefix

Change `com.rhythm.app` in: `project.yml` (each target's
`PRODUCT_BUNDLE_IDENTIFIER` + `options.bundleIdPrefix` + the watch's
`WKCompanionAppBundleIdentifier` + `BGTaskSchedulerPermittedIdentifiers`), and
the three `Config/*.entitlements` app-group strings. Then regenerate.

## 5. App config / secrets to set

- **RevenueCat API key** — replace `"your_revenuecat_api_key"` in
  `Core/Clients/PaywallClient.swift`.
- **Backend base URL** — replace `http://localhost:8080` in the networking
  clients (`Core/Clients/SyncClient.swift`, `AuthClient.swift`) with your
  deployed URL for release builds.
- Backend env (`OPENAI_API_KEY`, `JWT_SECRET`, Apple IDs) — see `backend/`.

## 6. Privacy strings (already in Info-App.plist)

HealthKit (share/update), Calendar (+ full-access), Microphone, Speech
Recognition — with human-readable, App-Store-ready copy. Review the wording
before submission.

## 7. What's verified

- ✅ `xcodegen generate` produces `Rhythm.xcodeproj` (all 4 targets, 2 configs).
- ✅ Swift Package graph resolves (TCA 1.17.0 + RevenueCat 5.83.0 + transitive).
- ✅ **The iOS app + widget compile for the simulator** (`BUILD SUCCEEDED`).
- ✅ **`RhythmTests` runs on the iPhone 16 simulator — 15/15 tests pass**
  (`TEST SUCCEEDED`): 10 `GentleStreak` unit tests, 2 `TimelineFeature` TCA
  reducer tests (streak computation), and 3 `AppFeature` TCA reducer tests
  (onboarding completion, ritual dismissal, cycle-complete → save + HealthKit).
- ✅ First-value onboarding gate and the gentle-streak header are wired in.

CLI build/test commands used (this environment's `xcodebuild` points at
CommandLineTools, and SPM macros need trusting, so):

```bash
cd ios/Rhythm
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project Rhythm.xcodeproj -scheme Rhythm \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -derivedDataPath .build/dd CODE_SIGNING_ALLOWED=NO -skipMacroValidation test
```

> ✅ **watchOS:** after installing the watch platform
> (`xcodebuild -downloadPlatform watchOS`), the `RhythmWatch` target **and the
> full scheme (app + widget + watch)** build, and all tests run **with the watch
> attached** — verified. On a machine that lacks the watchOS platform, either
> install it the same way or temporarily comment the `RhythmWatch` embed in
> `project.yml` and regenerate.

## 8. Remaining before it builds cleanly on device

The iOS app **compiles and its tests pass**, but before a signed device build /
App Store submission you'll still want to:

- Set your `DEVELOPMENT_TEAM` + real bundle-ID prefix and provide a real App Icon.
- Finish the remaining unwired integrations (Keychain token storage after
  sign-in, HealthKit water logging on ritual complete, App-Group writes so the
  widgets show live data, Watch ⇄ iPhone sync, 401→refresh→retry).
- Replace silent `try?` calls with user-facing error states.
- Compile-verify the `RhythmWatch` target on a machine with the watchOS SDK; the
  watch **complication** also needs its own watch widget-extension target to
  appear on a watch face. *(Update: `RhythmWatch` now compiles and the full
  scheme builds/tests with the watch attached; only the complication
  widget-extension remains.)*

## 9. Regeneration workflow

`Rhythm.xcodeproj` is git-ignored (see `.gitignore`) — commit `project.yml` and
regenerate after pulling. Any time you add files or change settings:

```bash
cd ios/Rhythm && xcodegen generate
```
