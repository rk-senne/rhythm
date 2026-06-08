# Rhythm — Technology Stack

**Document Version:** 1.0
**Date:** 29 May 2026
**Status:** Draft

---

## Stack Summary

```
iOS Client:   SwiftUI → TCA → SwiftData
Watch:        WatchKit + WatchConnectivity
Backend:      Go 1.22 + chi + PostgreSQL + Redis
AI:           OpenAI GPT-4 (weekly summaries, coaching)
Payments:     RevenueCat
Infra:        Fly.io → AWS EKS (at scale)
CI/CD:        GitHub Actions + Fastlane
Monitoring:   Prometheus + Grafana + TelemetryDeck
```

---

## iOS Client

| Layer | Technology | Version | Purpose |
|-------|-----------|---------|---------|
| **UI Framework** | SwiftUI | iOS 17+ | Declarative UI, Watch/Widget code sharing |
| **Architecture** | TCA (The Composable Architecture) | 1.x | Unidirectional data flow, testable reducers |
| **Persistence** | SwiftData | iOS 17+ | Local DB, iCloud sync, offline-first |
| **Networking** | URLSession + async/await | — | Native concurrency, no third-party HTTP lib |
| **Calendar** | EventKit | — | Read local/subscribed calendars |
| **Health** | HealthKit | — | Water intake sync (bidirectional) |
| **Focus Mode** | ManagedSettings + INFocusStatusCenter | iOS 16+ | Activate DND during focus sessions |
| **Notifications** | UNUserNotificationCenter | — | Scheduled ritual prompts |
| **Live Activity** | ActivityKit | iOS 16.1+ | Lock screen timer, Dynamic Island |
| **Voice** | Speech + AVFoundation | — | On-device transcription for voice journals |
| **Payments** | RevenueCat | 5.x | Subscription management, paywall A/B testing |
| **Analytics** | TelemetryDeck | — | Privacy-friendly, no PII collection |
| **Crash Reporting** | MetricKit + Sentry | — | Crash logs, performance metrics |

### Why These Choices

- **SwiftUI over UIKit:** Faster iteration, shared code with Watch/Widgets, modern lifecycle. iOS 17 minimum is acceptable (target audience has recent devices).
- **TCA over MVVM/Observation:** Timer + notifications + sync + calendar creates complex side-effect chains. TCA's explicit effect system prevents state bugs. TestStore makes testing trivial.
- **SwiftData over Core Data:** Less boilerplate, macro-based models, built-in CloudKit sync. Acceptable maturity for a new project.
- **No Alamofire/Moya:** URLSession with async/await is sufficient. Fewer dependencies = smaller binary, fewer supply chain risks.
- **TelemetryDeck over Firebase Analytics:** Privacy-first (no user tracking), GDPR-compliant by default, designed for indie apps.

---

## Apple Watch

| Layer | Technology | Purpose |
|-------|-----------|---------|
| **UI** | SwiftUI (WatchKit) | Watch-native views |
| **Communication** | WatchConnectivity | Sync state with iPhone |
| **Haptics** | WKInterfaceDevice | Breathe rhythm, ritual prompts |
| **Complications** | WidgetKit (watchOS 10+) | Cycle countdown on watch face |
| **Background** | WKExtendedRuntimeSession | Keep timer alive during wrist-down |

---

## Widgets

| Layer | Technology | Purpose |
|-------|-----------|---------|
| **Framework** | WidgetKit | Home screen + Lock screen widgets |
| **Types** | Small (progress ring), Lock screen (countdown) | Glanceable status |
| **Data** | App Groups + SwiftData | Shared container between app and widget |

---

## Backend

| Layer | Technology | Version | Purpose |
|-------|-----------|---------|---------|
| **Language** | Go | 1.22+ | Performance, concurrency, single binary |
| **Router** | chi | 5.x | Lightweight, middleware-friendly, stdlib-compatible |
| **Database** | PostgreSQL | 16 | Relational data, JSONB for flexible fields |
| **Migrations** | golang-migrate | 4.x | Version-controlled schema changes |
| **Cache/Queue** | Redis | 7 | Rate limiting, push notification queue, session cache |
| **Job Queue** | River | — | Postgres-backed background jobs (calendar sync, AI) |
| **Auth** | Custom (Apple Sign-In + JWT) | — | Minimal dependencies, full control |
| **Validation** | go-playground/validator | 10.x | Struct tag validation |
| **Logging** | slog (stdlib) | — | Structured logging, zero dependencies |
| **Config** | envconfig | — | 12-factor env var parsing |
| **Testing** | go test + testcontainers | — | Unit + integration with real Postgres |

### Why These Choices

- **Go over Node.js:** This backend is I/O-heavy (push notifications, calendar sync, WebSocket for teams). Goroutines handle 100K+ concurrent operations with minimal memory. Single binary = simple Docker images, fast Fly.io deploys.
- **chi over Gin/Echo/Fiber:** chi is closest to stdlib, uses standard `http.Handler` interface. Easy to swap out later. No framework lock-in.
- **River over BullMQ/Asynq:** Postgres-backed means no separate Redis dependency for jobs. Transactional job enqueue (create user + enqueue welcome email in one transaction).
- **slog over zerolog/zap:** Standard library since Go 1.21. No dependency, good enough performance, structured output.

---

## External Services

| Service | Purpose | Cost (at scale) |
|---------|---------|-----------------|
| **Apple APNs** | Push notifications | Free |
| **Google Calendar API** | Calendar sync | Free (quota-based) |
| **Microsoft Graph** | Outlook calendar + email | Free (quota-based) |
| **OpenAI API** | Weekly summaries, AI coach | ~$0.01-0.05/user/week |
| **RevenueCat** | Subscription management | Free <$2.5K MRR, then 1% |
| **Cloudflare R2** | Voice memo storage | $0.015/GB/month |
| **Resend** | Transactional email (weekly summary) | Free <3K emails/month |

---

## Infrastructure

| Layer | Technology | Phase |
|-------|-----------|-------|
| **Hosting** | Fly.io (2 regions) | Phase 1-3 |
| **Hosting (scale)** | AWS EKS | Phase 4+ (>50K DAU) |
| **Database** | Neon (serverless Postgres) | Phase 1-2 |
| **Database (scale)** | AWS RDS PostgreSQL | Phase 3+ |
| **Cache** | Upstash Redis (serverless) | Phase 1-2 |
| **Cache (scale)** | AWS ElastiCache | Phase 3+ |
| **CDN** | Cloudflare | All phases |
| **DNS** | Cloudflare | All phases |
| **Secrets** | Fly.io secrets / AWS Secrets Manager | Per phase |
| **IaC** | Terraform | Phase 2+ |

### Why Start on Fly.io

- $0 to start (free tier covers MVP)
- Deploy with `fly deploy` (one command)
- Auto-sleep when no traffic (saves money during low-usage periods)
- Multi-region when needed (add `fly scale count 2 --region lhr`)
- Easy migration path to containers on any platform

---

## CI/CD

| Stage | Tool | Trigger |
|-------|------|---------|
| **iOS Lint** | SwiftLint | Every PR |
| **iOS Test** | xcodebuild test | Every PR |
| **iOS Build** | Fastlane + xcodebuild | Version tag |
| **iOS Deploy** | Fastlane → TestFlight | Version tag |
| **Go Lint** | golangci-lint | Every PR |
| **Go Test** | go test + testcontainers | Every PR |
| **Go Build** | Docker build | Merge to main |
| **Go Deploy** | fly deploy | Merge to main |

---

## Development Tools

| Tool | Purpose |
|------|---------|
| Xcode 16+ | iOS development |
| GoLand / VS Code | Backend development |
| Proxyman | Network debugging (iOS ↔ API) |
| Postico | PostgreSQL GUI |
| TablePlus | Redis GUI |
| Figma | Design mockups |
| Linear | Issue tracking |
| GitHub | Source control + CI |

---

## Dependency Philosophy

1. **Minimize dependencies** — Use stdlib where possible (Go's net/http, Swift's URLSession)
2. **Pin versions** — Exact versions in go.mod, Package.resolved committed
3. **Audit regularly** — `go mod verify`, check for CVEs monthly
4. **No mega-frameworks** — Prefer small, focused libraries over kitchen-sink frameworks
5. **Exit strategy** — Every dependency should be replaceable without rewriting the app
