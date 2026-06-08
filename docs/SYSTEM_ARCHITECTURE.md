# Rhythm — System Architecture

**Document Version:** 1.0
**Date:** 29 May 2026
**Status:** Draft

---

## 1. Architecture Overview

Rhythm follows an **offline-first client with thin sync backend** pattern. The iOS app is fully functional without network connectivity. The Go backend provides sync, calendar integration, push notifications, and AI features.

### High-Level Topology

```
┌─────────────────────────────────────────────────────────────────┐
│                      Apple Ecosystem                             │
│                                                                 │
│  ┌──────────────┐    ┌──────────────┐    ┌────────────────┐    │
│  │   iPhone     │    │  Apple Watch │    │   Widgets      │    │
│  │   App        │◄──▶│   App        │    │  (WidgetKit)   │    │
│  │  (SwiftUI)   │    │  (WatchKit)  │    └───────┬────────┘    │
│  └──────┬───────┘    └──────────────┘            │             │
│         │         WatchConnectivity               │             │
│         │                                         │             │
│  ┌──────┴─────────────────────────────────────────┴──────┐     │
│  │                    SwiftData                           │     │
│  │              (Local Database + iCloud)                 │     │
│  └──────────────────────────┬────────────────────────────┘     │
│                             │                                   │
└─────────────────────────────┼───────────────────────────────────┘
                              │ HTTPS (REST)
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                       Go Backend (Fly.io)                        │
│                                                                 │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌──────────────────┐  │
│  │  Auth   │  │  Sync   │  │  Push   │  │  Calendar Sync   │  │
│  │ Service │  │ Service │  │ Service │  │  Worker          │  │
│  └────┬────┘  └────┬────┘  └────┬────┘  └────────┬─────────┘  │
│       └─────────────┴────────────┴────────────────┘            │
│                             │                                   │
└─────────────────────────────┼───────────────────────────────────┘
                              │
          ┌───────────────────┼───────────────────┐
          ▼                   ▼                   ▼
   ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
   │ PostgreSQL  │    │    Redis    │    │Cloudflare R2│
   │   (Neon)    │    │  (Upstash)  │    │  (Audio)    │
   └─────────────┘    └─────────────┘    └─────────────┘
                              │
          ┌───────────────────┼───────────────────┐
          ▼                   ▼                   ▼
   ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
   │  Apple APNs │    │ Google Cal  │    │  OpenAI     │
   │             │    │ MS Graph    │    │  (GPT-4)    │
   └─────────────┘    └─────────────┘    └─────────────┘
```

---

## 2. iOS Architecture

### Module Structure

```
Rhythm/
├── App/
│   ├── RhythmApp.swift              # Entry point, TCA store
│   └── AppDelegate.swift            # Push notification registration
├── Core/
│   ├── Models/                      # SwiftData @Model classes
│   ├── Clients/                     # TCA dependency clients
│   │   ├── TimerClient.swift        # Focus timer logic
│   │   ├── NotificationClient.swift # UNUserNotificationCenter wrapper
│   │   ├── HealthKitClient.swift    # Water intake sync
│   │   ├── CalendarClient.swift     # EventKit wrapper
│   │   ├── FocusModeClient.swift    # iOS Focus mode toggle
│   │   ├── SyncClient.swift         # Network sync to backend
│   │   └── AudioClient.swift        # Voice memo recording
│   └── Extensions/
├── Features/
│   ├── Timer/                       # Focus session feature
│   │   ├── TimerFeature.swift       # TCA Reducer
│   │   └── TimerView.swift
│   ├── Ritual/                      # Transition ritual feature
│   │   ├── RitualFeature.swift
│   │   ├── BreatheView.swift
│   │   ├── HydrateView.swift
│   │   └── JournalView.swift
│   ├── Timeline/                    # Daily rhythm view
│   │   ├── TimelineFeature.swift
│   │   └── TimelineView.swift
│   ├── Settings/
│   ├── Onboarding/
│   └── Paywall/
├── Watch/                           # WatchKit extension
│   ├── WatchApp.swift
│   ├── WatchTimerView.swift
│   └── WatchRitualView.swift
└── Widgets/
    ├── CycleCountdownWidget.swift
    └── DailyProgressWidget.swift
```

### State Management (TCA)

```
AppFeature (root)
├── TimerFeature          — Focus session state + effects
├── RitualFeature         — Breathe/hydrate/journal flow
├── TimelineFeature       — Daily view, cycle history
├── CalendarFeature       — Events, suggested blocks
├── SettingsFeature       — User preferences
├── SyncFeature           — Background sync coordination
└── PaywallFeature        — Subscription state
```

Each feature is a self-contained TCA reducer with:
- **State:** Value type describing the feature's data
- **Action:** Enum of all possible events
- **Reducer:** Pure function (state, action) → effect
- **Dependencies:** Injected clients (timer, notifications, etc.)

---

## 3. Backend Architecture

### Service Layout

```
rhythm-api/
├── cmd/
│   └── server/
│       └── main.go              # Entry point, wire dependencies
├── internal/
│   ├── auth/                    # Apple Sign-In, JWT
│   │   ├── handler.go
│   │   ├── service.go
│   │   └── middleware.go
│   ├── sync/                    # Data sync endpoints
│   │   ├── handler.go
│   │   └── service.go
│   ├── push/                    # APNs notification dispatch
│   │   ├── worker.go
│   │   └── apns.go
│   ├── calendar/                # OAuth + event fetching
│   │   ├── handler.go
│   │   ├── google.go
│   │   └── microsoft.go
│   ├── ai/                      # Weekly summary generation
│   │   └── summary.go
│   ├── team/                    # Team features (Phase 3)
│   │   ├── handler.go
│   │   └── service.go
│   └── storage/                 # PostgreSQL + Redis + R2
│       ├── postgres.go
│       ├── redis.go
│       └── r2.go
├── migrations/                  # SQL migrations
├── Dockerfile
├── fly.toml
└── go.mod
```

### Request Flow

```
Client Request
      │
      ▼
┌─────────────┐
│  chi Router │
└──────┬──────┘
       │
       ▼
┌─────────────┐     ┌─────────────┐
│  Middleware  │────▶│  Rate Limit │ (Redis)
│  Chain      │     │  Auth (JWT) │
└──────┬──────┘     └─────────────┘
       │
       ▼
┌─────────────┐
│   Handler   │ ← Validates request, calls service
└──────┬──────┘
       │
       ▼
┌─────────────┐
│   Service   │ ← Business logic
└──────┬──────┘
       │
       ▼
┌─────────────┐
│  Repository │ ← Database queries
└─────────────┘
```

---

## 4. Sync Protocol

### Design Principles

1. **Client is source of truth** — Server never overwrites local data without conflict resolution
2. **Append-only where possible** — Journal entries and hydration logs never conflict
3. **Timestamp-based pull** — Client sends `since` timestamp, server returns newer records
4. **Batch push** — Client batches local changes and pushes in one request

### Sync Flow

```
iPhone                              Server
  │                                    │
  │  POST /sync/push                   │
  │  {changes: [...], deviceId: "x"}   │
  │───────────────────────────────────▶│
  │                                    │── Write to DB
  │         200 OK {serverTime: T}     │
  │◀───────────────────────────────────│
  │                                    │
  │  GET /sync/pull?since=T            │
  │───────────────────────────────────▶│
  │                                    │── Query changes > T
  │  200 OK {changes: [...]}           │     for this user
  │◀───────────────────────────────────│
  │                                    │
  │── Merge into SwiftData             │
```

### Conflict Resolution

| Data Type | Strategy | Rationale |
|-----------|----------|-----------|
| Cycles | Last-write-wins (by `updated_at`) | Only one device active at a time |
| Journal entries | Append-only, no conflicts | Each entry is unique |
| Hydration logs | Append-only, dedupe by ID | Same |
| Settings | Last-write-wins | User intent is clear |
| Calendar connections | Server authoritative | OAuth tokens live server-side |

---

## 5. Push Notification Architecture

```
┌──────────────────────────────────────────────────┐
│              Notification Scheduler               │
│                                                  │
│  1. User completes onboarding → schedule cycles  │
│  2. Cron job recalculates daily at midnight      │
│  3. Calendar sync updates → reschedule           │
└──────────────────────┬───────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────┐
│              Redis Sorted Set                     │
│  Key: notifications:{user_id}                    │
│  Score: Unix timestamp of delivery               │
│  Value: {type, title, body, data}                │
└──────────────────────┬───────────────────────────┘
                       │
                       ▼ (Go worker polls every 30s)
┌──────────────────────────────────────────────────┐
│              Push Worker (goroutines)             │
│  • Batch fetch due notifications                 │
│  • Fan out to APNs HTTP/2 connections            │
│  • Mark as sent, handle failures/retries         │
└──────────────────────────────────────────────────┘
```

### Notification Types

| Type | Trigger | Content |
|------|---------|---------|
| `cycle_start` | Scheduled time | "Ready for your next focus block?" |
| `ritual_reminder` | Timer ends | "Time to breathe, hydrate, and reflect." |
| `hydration_nudge` | 2hr since last log | "Quick sip? You're at 4/8 glasses." |
| `weekly_summary` | Sunday 9am | "Your week in rhythm is ready." |
| `streak_risk` | 8pm, no cycles today | "One quick cycle to keep your streak?" |

---

## 6. Calendar Integration Architecture

```
┌─────────────┐         ┌─────────────┐         ┌──────────────┐
│   iPhone    │         │  Go Server  │         │ Google/MSFT  │
│  (EventKit) │         │             │         │   Calendar   │
└──────┬──────┘         └──────┬──────┘         └──────┬───────┘
       │                       │                       │
       │ Local calendars       │  OAuth2 flow          │
       │ (read-only via        │◀─────────────────────▶│
       │  EventKit)            │                       │
       │                       │  Webhook / polling    │
       │                       │◀──────────────────────│
       │                       │                       │
       │  GET /calendar/events │                       │
       │──────────────────────▶│                       │
       │                       │                       │
       │  Merged events        │                       │
       │  (local + remote)     │                       │
       │◀──────────────────────│                       │
```

**Dual approach:**
- **Local calendars** (Apple Calendar, subscribed): Read via EventKit on-device. No server needed.
- **Google/Outlook**: OAuth tokens stored server-side. Server fetches events and returns merged view. This enables cross-device sync and background scheduling.

---

## 7. Security Architecture

| Layer | Measure |
|-------|---------|
| Transport | TLS 1.3 everywhere, certificate pinning on iOS |
| Auth | Apple Sign-In (no passwords), JWT with 15-min expiry + refresh tokens |
| Data at rest | SwiftData encrypted by iOS Data Protection. Server: PostgreSQL TDE |
| API | Rate limiting (100 req/min), input validation (Go struct tags) |
| Secrets | Fly.io secrets for env vars, no secrets in code |
| Calendar tokens | AES-256 encrypted in DB, decrypted only in memory during use |
| Audio files | Signed URLs with 1-hour expiry, no public access |
| GDPR | Data export endpoint, account deletion (cascade all data) |

---

## 8. Observability

| Signal | Tool | Purpose |
|--------|------|---------|
| Metrics | Prometheus + Grafana | Request latency, sync throughput, push delivery rate |
| Logs | Structured JSON → Loki | Error tracking, audit trail |
| Traces | OpenTelemetry → Tempo | Request flow across services |
| Alerts | Grafana Alerting | Error rate spike, push failure rate, DB connection pool exhaustion |
| iOS | MetricKit + TelemetryDeck | Crash reports, performance, privacy-friendly analytics |

---

## 9. Failure Modes & Recovery

| Failure | Impact | Recovery |
|---------|--------|----------|
| Backend down | App works offline, sync pauses | Exponential backoff retry, user sees "syncing..." badge |
| PostgreSQL down | No new signups, no sync | Fly.io auto-restart, connection pool retry |
| Redis down | Push notifications delayed | Fall back to polling, notifications queue in memory |
| APNs unreachable | Notifications not delivered | Retry with backoff, iOS local notifications as fallback |
| Calendar OAuth expired | Stale calendar data | Background token refresh, prompt re-auth if refresh fails |
| OpenAI API down | Weekly summary delayed | Queue and retry, show "summary generating..." state |
