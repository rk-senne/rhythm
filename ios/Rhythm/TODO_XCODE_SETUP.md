# iOS Project Setup — SUPERSEDED

> The Xcode project is now **generated from `project.yml`** (XcodeGen).
> Run `xcodegen generate` in this directory, then open `Rhythm.xcodeproj`.
> Full guide: `docs/XCODE_SETUP.md`.

Handled by the generated project (`project.yml`):
- [x] Create Xcode project (iOS App target, iOS 17)
- [x] Add Watch App target (watchOS 10)
- [x] Add Widget Extension target
- [x] Add App Group entitlement for app ⇄ widget ⇄ watch (`group.com.rhythm.app`)
- [x] SPM dependencies wired (TCA 1.17.0 + RevenueCat 5.x) — resolve on first open
- [x] Entitlements + Info.plist privacy strings (HealthKit, Calendar, Mic, Push, Sign in with Apple, Live Activities)
- [x] All source files assigned to their targets; unit test target with GentleStreak tests

Still manual (see docs/XCODE_SETUP.md → "Remaining before it builds cleanly"):
- [ ] Set your `DEVELOPMENT_TEAM` + real bundle-ID prefix
- [ ] Family Controls entitlement (needs Apple approval) if using ManagedSettings
- [ ] Real RevenueCat API key in `Core/Clients/PaywallClient.swift`
- [ ] Backend base URL (replace `http://localhost:8080`)
- [ ] Provide a real App Icon image; finish skeleton wiring (see ../../CRITICAL_NOTES.md)
