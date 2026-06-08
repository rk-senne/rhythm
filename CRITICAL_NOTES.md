# Rhythm — Critical TODO Before You Can Run / Ship

## 🔴 Must Do (Won't build/run without these)

### iOS
- [ ] **Create Xcode project** — Add iOS app, Watch app, Widget extension targets. Add all source files to correct targets.
- [ ] **Resolve SPM dependencies** — Add TCA and RevenueCat packages in Xcode (File → Add Package Dependencies)
- [ ] **Signing & Capabilities** — Add: HealthKit, Push Notifications, Background Modes, App Groups, Sign in with Apple
- [ ] **Info.plist entries** — NSHealthShareUsageDescription, NSHealthUpdateUsageDescription, NSCalendarsUsageDescription, NSMicrophoneUsageDescription
- [ ] **App Group** — Create shared container (e.g. `group.com.yourcompany.rhythm`) for widget ↔ app data sharing
- [ ] **Live Activity entitlement** — Enable in target capabilities (Supports Live Activities = YES)
- [ ] **Family Controls / Screen Time** — ManagedSettings requires Family Controls capability + entitlement (apply via Apple developer portal)

### Backend
- [ ] **Install Go 1.22+** — Then run `go mod tidy` in `/backend` to generate `go.sum`
- [ ] **Set OPENAI_API_KEY** — Required for AI weekly summary endpoint
- [ ] **RevenueCat API key** — Replace `"your_revenuecat_api_key"` in PaywallClient.swift
- [ ] **Backend base URL** — Replace all `http://localhost:8080` references with your actual Fly.io URL for production

## 🟡 Should Do (Before TestFlight)

- [ ] **Tests** — No tests written yet. At minimum: TimerFeature reducer tests, sync endpoint integration tests
- [ ] **Error handling** — Most network calls use `try?` (silent failures). Add user-facing error states.
- [ ] **Keychain: store tokens after sign-in** — AuthClient returns tokens but nothing calls KeychainClient.save yet. Wire this in AppFeature after successful sign-in.
- [ ] **Onboarding gating** — AppView should check if onboarding is complete and show OnboardingView if not (use UserDefaults flag)
- [ ] **HealthKit: log water on ritual complete** — AppFeature saves to SwiftData but doesn't call `healthKitClient.logWaterIntake` yet
- [ ] **Widget data** — Widgets read from App Group container. Need to write cycle count there when cycles complete.
- [ ] **Watch ↔ iPhone sync** — WatchConnectivity not yet implemented. Watch operates independently for now.
- [ ] **Token refresh** — SyncClient and pull don't handle 401 → refresh → retry flow yet

## 🟢 Nice to Have (Before App Store)

- [ ] **Rate limiting on iOS** — Debounce settings saves, don't sync on every single foreground
- [ ] **Offline queue** — Failed sync pushes should queue and retry
- [ ] **Analytics** — Add TelemetryDeck SDK, track key events (cycle_completed, ritual_skipped, etc.)
- [ ] **Accessibility** — VoiceOver labels on breathe animation, Dynamic Type support
- [ ] **Localization** — Extract all strings to Localizable.strings
- [ ] **App Store assets** — Screenshots, preview video, description, keywords

## 📁 Project Structure Reference

```
rhythm/
├── docs/                    # Design docs (done)
├── ios/Rhythm/
│   ├── App/                 # Entry point, root feature
│   ├── Core/Models/         # SwiftData models
│   ├── Core/Clients/        # TCA dependency clients
│   ├── Features/            # Timer, Ritual, Timeline, Settings, Calendar, Paywall, Onboarding
│   ├── Watch/               # WatchKit app + complication
│   └── Widgets/             # WidgetBundle (3 widgets)
├── backend/
│   ├── cmd/server/          # Entry point
│   ├── internal/            # auth, sync, push, ai, storage, config
│   ├── migrations/          # SQL
│   ├── docker-compose.yml   # Local Postgres + Redis
│   └── Dockerfile + fly.toml
└── TODO_XCODE_SETUP.md
```

## 🚀 Quick Start Commands

```bash
# Backend
cd rhythm/backend
docker compose up -d
cp .env.example .env
go mod tidy
go run ./cmd/server

# iOS
# Open Xcode → Create new project → Add existing files → Resolve packages → Build
```
