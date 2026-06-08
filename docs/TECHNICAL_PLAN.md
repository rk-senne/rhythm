# Rhythm — Technical Plan

**Document Version:** 1.0
**Date:** 29 May 2026
**Status:** Draft

---

## 1. Development Phases

### Phase 1 — MVP (Weeks 1–8)

**Goal:** Core rhythm loop on iPhone. TestFlight beta.

| Week | Deliverable | Details |
|------|-------------|---------|
| 1 | Project scaffolding | Xcode project, TCA setup, SwiftData models, CI pipeline |
| 2 | Data layer | SwiftData schemas (Cycle, JournalEntry, HydrationLog, UserSettings), migrations |
| 3 | Focus timer | Countdown timer, background execution, Live Activity, iOS Focus mode toggle |
| 4 | Transition ritual | Breathe animation (haptic-synced), hydration tap, text journal input |
| 5 | Daily timeline | Visual rhythm view showing completed/upcoming cycles, scroll-to-now |
| 6 | Notifications | Scheduled cycle reminders, smart timing (don't interrupt active focus) |
| 7 | Go backend | Auth service (Apple Sign-In + JWT), user model, sync endpoint, PostgreSQL |
| 8 | Polish + TestFlight | Onboarding flow, settings, bug fixes, 50-100 beta testers |

**Exit criteria:** User can complete 3+ full cycles/day with timer + ritual + journal.

---

### Phase 2 — Watch + Calendar (Weeks 9–16)

**Goal:** Differentiated product. App Store launch.

| Week | Deliverable | Details |
|------|-------------|---------|
| 9 | Watch app — timer | WatchKit UI, haptic breathe, complication showing current cycle |
| 10 | Watch app — ritual | Tap-to-hydrate, voice journal (on-device transcription), sync to iPhone |
| 11 | Calendar read | EventKit integration, display meetings in timeline, detect free blocks |
| 12 | Auto-scheduling | Suggest focus blocks in calendar gaps, one-tap accept |
| 13 | Widgets | Lock screen (next cycle countdown), home screen (daily progress ring) |
| 14 | AI weekly summary | Send journal entries to GPT-4, generate weekly reflection |
| 15 | Paywall + RevenueCat | Subscription flow, restore purchases, receipt validation |
| 16 | App Store submission | Screenshots, preview video, ASO keywords, review guidelines compliance |

**Exit criteria:** App Store approved, Watch app functional, calendar-aware scheduling works.

---

### Phase 3 — Growth Features (Weeks 17–28)

| Week | Deliverable |
|------|-------------|
| 17-18 | Google Calendar OAuth sync (server-side, bidirectional) |
| 19-20 | Microsoft Outlook / Graph API integration |
| 21 | Email morning briefing (top 5 emails needing response) |
| 22-23 | Team Rhythm — shared focus hours, presence indicators |
| 24 | Slack integration (auto-set status during focus) |
| 25-26 | AI Coach — pattern detection, personalized suggestions |
| 27 | Siri Shortcuts ("Start my focus", "Log water", "What's next?") |
| 28 | Performance audit, accessibility pass, localization (ES, DE, JA) |

---

### Phase 4 — Scale (Months 7–12)

- Android app (evaluate: Kotlin native vs KMP for shared logic)
- Enterprise tier (SSO via SAML, admin dashboard, usage analytics)
- Public API for third-party integrations
- Infrastructure migration to AWS EKS if >50K DAU
- iPad app with split-view timeline

---

## 2. Technical Decisions

### ADR-001: TCA over MVVM

**Context:** Need testable, predictable state management for complex timer + notification + sync interactions.
**Decision:** Use The Composable Architecture (TCA) by Point-Free.
**Rationale:** Unidirectional data flow, built-in dependency injection, excellent testing story, handles side effects (timers, notifications) declaratively.
**Trade-off:** Steeper learning curve, more boilerplate than vanilla SwiftUI.

### ADR-002: SwiftData over Core Data

**Context:** Need local persistence with iCloud sync capability.
**Decision:** SwiftData (iOS 17+).
**Rationale:** Modern API, macro-based models, built-in CloudKit sync, less boilerplate than Core Data. iOS 17+ minimum is acceptable (90%+ of target audience).
**Trade-off:** Less mature than Core Data, fewer escape hatches for complex queries.

### ADR-003: Go over Node.js for Backend

**Context:** Backend handles push notifications, calendar sync, and eventually WebSocket connections for team features.
**Decision:** Go with chi router.
**Rationale:**
- Single binary deployment (simple Docker images, fast cold starts on Fly.io)
- Goroutines handle concurrent calendar syncs and push notification fanout efficiently
- Low memory footprint (~50MB vs ~300MB for Node)
- Strong standard library for HTTP, JSON, crypto
- No runtime dependencies

**Trade-off:** No shared types with iOS client (mitigated by OpenAPI spec generation).

### ADR-004: Offline-First with Eventual Sync

**Context:** Users may be in airplane mode, underground, or have spotty connectivity.
**Decision:** All data writes go to SwiftData first. Background sync to server is opportunistic.
**Rationale:** The app must never feel broken due to network issues. Focus timer and rituals are entirely local operations.
**Conflict resolution:** Last-write-wins for settings/preferences. Append-only for journal entries (no conflicts possible). Server timestamp for ordering.

### ADR-005: RevenueCat for Subscriptions

**Context:** Need subscription management, receipt validation, analytics.
**Decision:** RevenueCat SDK.
**Rationale:** Handles Apple receipt validation, offers A/B testing for paywalls, provides revenue analytics, supports promotional offers. Free up to $2.5K MRR.
**Trade-off:** 1% revenue fee above free tier. Worth it vs building custom receipt validation.

---

## 3. API Design

### Authentication

```
POST /auth/apple       — Exchange Apple ID token for JWT
POST /auth/refresh     — Refresh expired JWT
DELETE /auth/session   — Logout
```

### Sync

```
POST /sync/push        — Push local changes to server (batch)
GET  /sync/pull?since= — Pull changes since timestamp
```

### Cycles

```
GET    /cycles?date=   — Get cycles for a date
POST   /cycles         — Create/complete a cycle
```

### Journal

```
GET    /journal?from=&to= — Get entries in date range
POST   /journal           — Create entry
POST   /journal/audio     — Upload voice memo
```

### Calendar

```
GET    /calendar/sync-status  — Check OAuth token validity
POST   /calendar/connect      — Initiate OAuth flow
GET    /calendar/events?date= — Get events for scheduling
POST   /calendar/suggest      — Get AI-suggested focus blocks
```

### Team (Phase 3)

```
POST   /teams                 — Create team
GET    /teams/:id/focus       — Get team focus status
POST   /teams/:id/focus/start — Signal focus start to team
```

---

## 4. Data Models

### iOS (SwiftData)

```swift
@Model class Cycle {
    var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var plannedDuration: Int // minutes
    var actualDuration: Int?
    var status: CycleStatus // .active, .completed, .skipped, .interrupted
    var ritualCompleted: Bool
    var hydratedDuring: Bool
    var syncedAt: Date?
}

@Model class JournalEntry {
    var id: UUID
    var cycleId: UUID?
    var createdAt: Date
    var text: String
    var audioURL: URL?
    var mood: Mood? // .great, .good, .neutral, .low, .rough
    var syncedAt: Date?
}

@Model class HydrationLog {
    var id: UUID
    var loggedAt: Date
    var amount: Int // ml
    var syncedAt: Date?
}

@Model class UserSettings {
    var cycleDuration: Int // default 90
    var dailyCycleGoal: Int // default 4
    var hydrationGoalMl: Int // default 2000
    var ritualBreatheDuration: Int // seconds, default 60
    var quietHoursStart: Date?
    var quietHoursEnd: Date?
    var calendarIntegrationEnabled: Bool
}
```

### PostgreSQL

```sql
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    apple_id TEXT UNIQUE NOT NULL,
    email TEXT,
    display_name TEXT,
    timezone TEXT NOT NULL DEFAULT 'UTC',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE cycles (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES users(id),
    started_at TIMESTAMPTZ NOT NULL,
    ended_at TIMESTAMPTZ,
    planned_duration INT NOT NULL,
    actual_duration INT,
    status TEXT NOT NULL DEFAULT 'completed',
    ritual_completed BOOLEAN DEFAULT false,
    hydrated_during BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE journal_entries (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES users(id),
    cycle_id UUID REFERENCES cycles(id),
    text TEXT NOT NULL,
    audio_key TEXT, -- S3/R2 object key
    mood TEXT,
    created_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE hydration_logs (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES users(id),
    amount_ml INT NOT NULL,
    logged_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE calendar_connections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id),
    provider TEXT NOT NULL, -- 'google', 'microsoft'
    access_token TEXT NOT NULL,
    refresh_token TEXT NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);
```

---

## 5. Testing Strategy

| Layer | Tool | Coverage Target |
|-------|------|----------------|
| iOS Unit (TCA reducers) | XCTest + TCA TestStore | 80%+ |
| iOS Snapshot | swift-snapshot-testing | All screens, light/dark, accessibility sizes |
| iOS Integration | XCUITest | Core flows (complete cycle, journal, settings) |
| Go Unit | go test | 85%+ |
| Go Integration | testcontainers-go | DB queries, auth flows |
| API Contract | OpenAPI spec + Prism mock | Client/server agreement |
| E2E | Detox or XCUITest | Happy path: signup → complete cycle → sync |

---

## 6. CI/CD Pipeline

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│  Git Push   │────▶│ GitHub Actions│────▶│  Artifacts  │
└─────────────┘     └──────┬───────┘     └─────────────┘
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
        ┌──────────┐ ┌──────────┐ ┌──────────┐
        │ iOS Build│ │ Go Build │ │  Lint    │
        │ + Test   │ │ + Test   │ │ + Format │
        └────┬─────┘ └────┬─────┘ └──────────┘
             │             │
             ▼             ▼
      ┌────────────┐ ┌────────────┐
      │ TestFlight │ │  Fly.io    │
      │ (on tag)   │ │  Deploy    │
      └────────────┘ └────────────┘
```

- **iOS:** xcodebuild test → archive → upload to TestFlight (on version tag)
- **Go:** go test → go build → Docker image → fly deploy (on main merge)
- **Lint:** SwiftLint (iOS), golangci-lint (Go)
