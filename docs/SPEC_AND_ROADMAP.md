# Rhythm — Specification & Roadmap

**Document Version:** 1.0
**Date:** 29 May 2026
**Status:** Draft

---

## 1. Product Specification

### Core Concept

Rhythm structures your workday into **cycles** aligned with the body's natural ultradian rhythm (90-120 minutes). Each cycle consists of:

1. **Focus Session** (45-90 min) — Deep work with DND active
2. **Transition Ritual** (5-10 min) — Breathe → Hydrate → Reflect
3. **Prepare** (1-2 min) — Preview next calendar event or start next cycle

### Feature Specification

#### F1: Focus Timer

| Attribute | Spec |
|-----------|------|
| Duration options | 45, 60, 90 min (custom in Pro) |
| Background execution | Yes (BackgroundTasks framework) |
| Live Activity | Lock screen countdown + Dynamic Island |
| Focus Mode | Auto-enable iOS Focus (configurable) |
| Interruption handling | Pause on phone call, resume after |
| Early end | Tap to end early, still counts as partial cycle |
| Sound | Optional start/end chime |

#### F2: Transition Ritual

| Attribute | Spec |
|-----------|------|
| Steps | Breathe → Hydrate → Reflect (fixed order) |
| Breathe duration | 4 breaths (4s in, 4s out) = ~60 seconds |
| Breathe feedback | Expanding circle + haptics synced to rhythm |
| Hydrate | Binary (yes/no) + optional amount (ml) |
| Reflect | Text input (max 280 chars) OR voice memo (max 30s) |
| Mood | Optional emoji picker (5 options) |
| Skip | Any step skippable, ritual still counts as done |
| Total time | 3-5 minutes typical |

#### F3: Hydration Tracking

| Attribute | Spec |
|-----------|------|
| Daily goal | Default 2000ml, configurable |
| Log methods | Ritual prompt, quick-add button, Watch tap |
| HealthKit sync | Write water intake to Health app |
| Reminders | Only during ritual (no separate hydration notifications) |
| Visualization | Progress bar on timeline, daily total |

#### F4: Micro-Journal

| Attribute | Spec |
|-----------|------|
| Entry types | Text (keyboard), Voice (transcribed on-device) |
| Max length | 280 chars text, 30s audio |
| Mood tagging | Optional (great/good/neutral/low/rough) |
| Linked to cycle | Auto-associated with preceding focus block |
| History view | Scrollable list, filterable by date/mood |
| Export | Plain text, JSON, or PDF (Pro) |
| AI Summary | Weekly digest of entries (Pro) |

#### F5: Calendar Integration

| Attribute | Spec |
|-----------|------|
| Local calendars | Read via EventKit (no server needed) |
| Google Calendar | OAuth2, server-side sync |
| Outlook | Microsoft Graph API, server-side sync |
| Display | Meetings shown in timeline alongside focus blocks |
| Auto-scheduling | Suggest focus blocks in free gaps (one-tap accept) |
| Conflict detection | Warn if focus block overlaps with meeting |
| Write-back | Optional: create "Focus Block" event in calendar (Pro) |

#### F6: Apple Watch

| Attribute | Spec |
|-----------|------|
| Timer | Full countdown with haptic alerts |
| Breathe | Haptic-guided breathing (no screen needed) |
| Hydrate | Tap to log from wrist |
| Journal | Voice memo via Watch mic |
| Complication | Current cycle status / next ritual time |
| Standalone | Requires iPhone nearby (WatchConnectivity) |

#### F7: Widgets

| Attribute | Spec |
|-----------|------|
| Lock screen | Next cycle countdown (circular) |
| Home screen small | Daily progress ring (cycles completed) |
| Home screen medium | Mini timeline (next 3 hours) |
| Update frequency | Every 15 min (WidgetKit limitation) |

---

## 2. Roadmap

### Phase 1: Foundation (Weeks 1-8)

**Theme:** Core loop on iPhone

```
Week 1-2: ████████░░ Project setup, data models, architecture
Week 3-4: ████████░░ Focus timer + iOS Focus integration
Week 5:   ████░░░░░░ Transition ritual (breathe + hydrate + journal)
Week 6:   ████░░░░░░ Timeline view + notifications
Week 7:   ████░░░░░░ Go backend (auth + sync)
Week 8:   ████░░░░░░ TestFlight beta
```

**Milestone:** User can complete 3+ full cycles/day with timer + ritual + journal.

**Deliverables:**
- [ ] Xcode project with TCA architecture
- [ ] SwiftData models (Cycle, JournalEntry, HydrationLog, Settings)
- [ ] Focus timer with background execution + Live Activity
- [ ] Ritual flow (breathe animation, hydrate tap, text journal)
- [ ] Daily timeline view
- [ ] Notification scheduling
- [ ] Go API: auth (Apple Sign-In), sync endpoints
- [ ] TestFlight build distributed to 50-100 testers

---

### Phase 2: Differentiation (Weeks 9-16)

**Theme:** Watch + Calendar + App Store launch

```
Week 9-10:  ████████░░ Apple Watch app
Week 11-12: ████████░░ Calendar integration (EventKit)
Week 13:    ████░░░░░░ Widgets (lock screen + home)
Week 14:    ████░░░░░░ AI weekly summary
Week 15:    ████░░░░░░ Paywall + RevenueCat
Week 16:    ████░░░░░░ App Store submission
```

**Milestone:** App Store approved. Watch app functional. Calendar-aware scheduling.

**Deliverables:**
- [ ] WatchKit app (timer, breathe haptics, hydrate tap, voice journal)
- [ ] EventKit calendar read + display in timeline
- [ ] Auto-suggest focus blocks in calendar gaps
- [ ] WidgetKit (lock screen countdown, home screen progress)
- [ ] OpenAI integration for weekly journal summary
- [ ] RevenueCat paywall (Pro tier)
- [ ] App Store listing (screenshots, preview video, ASO)
- [ ] Marketing site live

---

### Phase 3: Growth (Weeks 17-28)

**Theme:** External integrations + team features

```
Week 17-18: ████████░░ Google Calendar OAuth sync
Week 19-20: ████████░░ Microsoft Outlook integration
Week 21:    ████░░░░░░ Email morning briefing
Week 22-24: ████████████ Team Rhythm (shared focus, Slack)
Week 25-26: ████████░░ AI Coach (pattern detection)
Week 27:    ████░░░░░░ Siri Shortcuts
Week 28:    ████░░░░░░ Localization + accessibility audit
```

**Milestone:** Team tier launched. 3 calendar providers supported. AI coaching active.

**Deliverables:**
- [ ] Server-side Google Calendar sync (OAuth2 + webhook)
- [ ] Server-side Outlook sync (Microsoft Graph)
- [ ] Morning email briefing (top emails needing response)
- [ ] Team creation, shared focus hours, presence indicators
- [ ] Slack integration (auto-set status during focus)
- [ ] AI Coach: "You're less productive after 3pm meetings" type insights
- [ ] Siri: "Start my focus", "Log water", "What's next?"
- [ ] Localized: English, Spanish, German, Japanese

---

### Phase 4: Scale (Months 7-12)

**Theme:** Platform expansion + enterprise

| Month | Deliverable |
|-------|-------------|
| 7 | Android evaluation (Kotlin native vs KMP) |
| 8-9 | Android MVP (timer + ritual + sync) |
| 10 | Enterprise tier (SSO, admin dashboard) |
| 11 | iPad app (split-view timeline) |
| 12 | Public API, third-party integrations |

---

### Phase 5: Platform (Year 2)

- Mac app (Catalyst or native SwiftUI)
- Web dashboard for teams
- Integrations marketplace (Notion, Todoist, Linear)
- Hardware partnerships (smart water bottles with NFC tap-to-log)
- Wearable expansion (Garmin, Fitbit — if market demands)

---

## 3. Release Milestones

| Version | Date (Target) | Content |
|---------|--------------|---------|
| 0.1.0 | Week 8 | TestFlight beta — core loop |
| 0.5.0 | Week 14 | Feature-complete for launch |
| 1.0.0 | Week 16 | App Store launch |
| 1.1.0 | Week 20 | Google/Outlook calendar sync |
| 1.2.0 | Week 24 | Team Rhythm |
| 1.3.0 | Week 28 | AI Coach + Siri |
| 2.0.0 | Month 9 | Android launch |

---

## 4. Non-Goals (Explicitly Out of Scope)

| Feature | Why Not |
|---------|---------|
| Full to-do list / task manager | Competing with Todoist/Things. We're about rhythm, not tasks. |
| Long-form journaling | Day One owns this. We do micro-entries only. |
| Meditation courses | Headspace/Calm territory. We do 60-second breathwork only. |
| Social features / feed | Adds complexity, privacy concerns, not core to the value prop. |
| Gamification (XP, levels, badges) | Conflicts with "calm productivity" brand. Gentle streaks only. |
| Calorie/food tracking | Scope creep. HealthKit integration is enough. |

---

## 5. Success Metrics by Phase

| Phase | Key Metric | Target |
|-------|-----------|--------|
| 1 (Beta) | Beta tester retention (Day 7) | >40% |
| 2 (Launch) | App Store rating | ≥4.5 |
| 2 (Launch) | Week 1 downloads | >2,000 |
| 3 (Growth) | Free→Paid conversion | >5% |
| 3 (Growth) | Monthly churn | <10% |
| 4 (Scale) | DAU | >30,000 |
| 4 (Scale) | MRR | >$10,000 |
