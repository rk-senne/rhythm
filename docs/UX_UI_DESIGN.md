# Rhythm — UX & UI Design System

**Document Version:** 1.0
**Date:** 29 May 2026
**Status:** Draft

---

## 1. Design Philosophy

**Calm productivity.** The app should feel like a deep breath — not another source of anxiety. Every interaction should be intentional, minimal, and rewarding.

### Principles

1. **One thing at a time** — Never show the user two decisions simultaneously
2. **Gentle, not gamified** — No aggressive streaks, no guilt. Encouragement without pressure.
3. **Glanceable** — Key info visible in <1 second (Watch, widgets, timeline)
4. **Sensory-rich** — Haptics, subtle animations, and sound design matter as much as visuals
5. **Invisible when working** — During focus mode, the app disappears. It only surfaces during transitions.

---

## 2. Visual Identity

### Color Palette

```
Primary:        #4A6741  (Sage green — calm, natural, focus)
Secondary:      #E8A838  (Warm amber — energy, transition, ritual)
Background:     #FAFAF8  (Warm white — light mode)
Dark BG:        #1A1A1A  (Soft black — dark mode)
Surface:        #F2F0EC  (Warm gray — cards, panels)
Dark Surface:   #2A2A2A
Text Primary:   #1A1A1A / #FAFAF8
Text Secondary: #6B6B6B / #A0A0A0
Success:        #4A6741  (Same as primary — completing a cycle IS success)
Warning:        #D4763A  (Soft orange — gentle nudge)
Error:          #C44B4B  (Muted red — rare, only for real problems)
```

### Typography

| Use | Font | Size | Weight |
|-----|------|------|--------|
| Timer display | SF Rounded | 72pt | Ultralight |
| Section headers | SF Pro Display | 22pt | Semibold |
| Body text | SF Pro Text | 17pt | Regular |
| Captions | SF Pro Text | 13pt | Regular |
| Watch timer | SF Rounded | 42pt | Light |

### Iconography

- SF Symbols throughout (native, accessible, dynamic sizing)
- Custom icons only for: app icon, ritual illustrations
- Line weight: Regular (not thin, not bold)

### Motion

| Element | Animation | Duration | Curve |
|---------|-----------|----------|-------|
| Breathe circle | Scale 1.0 → 1.4 → 1.0 | 4s inhale, 4s exhale | easeInOut |
| Timer progress | Circular stroke | Continuous | linear |
| Screen transitions | Slide + fade | 0.3s | spring(0.8) |
| Completion checkmark | Scale bounce | 0.5s | spring(0.6, 0.8) |
| Card appear | Fade + slide up | 0.25s | easeOut |

---

## 3. Screen Map

```
┌─────────────────────────────────────────────────┐
│                  App Structure                    │
│                                                 │
│  ┌───────────┐                                  │
│  │ Onboarding│ (first launch only)              │
│  └─────┬─────┘                                  │
│        ▼                                        │
│  ┌───────────┐                                  │
│  │  Timeline │ ← HOME (daily rhythm view)       │
│  └─────┬─────┘                                  │
│        │                                        │
│   ┌────┼────┬──────────┐                        │
│   ▼    ▼    ▼          ▼                        │
│ ┌────┐┌────┐┌────────┐┌────────┐               │
│ │Focus││Rit-││Journal ││Settings│               │
│ │Timer││ual ││History ││        │               │
│ └────┘└────┘└────────┘└────────┘               │
│        │                                        │
│   ┌────┼────┐                                   │
│   ▼    ▼    ▼                                   │
│ ┌────┐┌────┐┌────┐                             │
│ │Brea││Hydr││Jour│                             │
│ │the ││ate ││nal │                             │
│ └────┘└────┘└────┘                             │
└─────────────────────────────────────────────────┘
```

---

## 4. Key Screens

### 4.1 Timeline (Home)

The primary screen. A vertical timeline of today's rhythm.

```
┌─────────────────────────────────┐
│  ☀️ Friday, 29 May              │
│  3 of 4 cycles complete         │
│                                 │
│  ┌─ 08:00 ─────────────────┐   │
│  │ ✅ Focus: Deep work      │   │
│  │    90 min · Ritual done  │   │
│  └──────────────────────────┘   │
│           │                     │
│  ┌─ 10:00 ─────────────────┐   │
│  │ 📅 Team standup (30min)  │   │
│  └──────────────────────────┘   │
│           │                     │
│  ┌─ 10:30 ─────────────────┐   │
│  │ ✅ Focus: Feature work   │   │
│  │    60 min · Ritual done  │   │
│  └──────────────────────────┘   │
│           │                     │
│  ┌─ 12:00 ─────────────────┐   │
│  │ 🔵 Focus: Writing        │   │  ← ACTIVE
│  │    ⏱ 34:22 remaining     │   │
│  └──────────────────────────┘   │
│           │                     │
│  ┌─ 14:00 ─────────────────┐   │
│  │ ○ Available block        │   │
│  │   [Start Focus]          │   │
│  └──────────────────────────┘   │
│                                 │
│  💧 1.2L / 2.0L    📝 3 notes  │
│                                 │
│  [─────── Tab Bar ───────────]  │
│  Timeline  Journal  Settings    │
└─────────────────────────────────┘
```

### 4.2 Focus Timer (Active)

Full-screen, minimal. Only the timer and a stop button.

```
┌─────────────────────────────────┐
│                                 │
│         Feature work            │
│                                 │
│                                 │
│           ┌─────┐              │
│          /       \             │
│         │  34:22  │            │
│          \       /             │
│           └─────┘              │
│      (circular progress ring)   │
│                                 │
│                                 │
│                                 │
│         [ ⏸ Pause ]            │
│                                 │
│    Tap to end early             │
└─────────────────────────────────┘
```

- Background: solid dark/light (no distractions)
- Live Activity shows timer on lock screen
- Dynamic Island shows countdown (iPhone 14 Pro+)

### 4.3 Transition Ritual

Three-step flow, one screen at a time. Swipe or auto-advance.

**Step 1: Breathe**
```
┌─────────────────────────────────┐
│                                 │
│         Breathe                 │
│                                 │
│                                 │
│           ○                     │
│         ○   ○                   │  ← Expanding/contracting
│        ○     ○                  │     circle with haptics
│         ○   ○                   │
│           ○                     │
│                                 │
│        Inhale...                │
│                                 │
│     4 breaths remaining         │
│                                 │
│        [Skip →]                 │
└─────────────────────────────────┘
```

**Step 2: Hydrate**
```
┌─────────────────────────────────┐
│                                 │
│         Hydrate                 │
│                                 │
│         💧                      │
│                                 │
│    Did you drink water?         │
│                                 │
│   ┌─────────┐  ┌─────────┐    │
│   │  Yes ✓  │  │  Skip   │    │
│   └─────────┘  └─────────┘    │
│                                 │
│    Today: 1.2L / 2.0L          │
│    ████████░░░░ 60%             │
│                                 │
└─────────────────────────────────┘
```

**Step 3: Reflect**
```
┌─────────────────────────────────┐
│                                 │
│         Quick note              │
│                                 │
│   What happened this block?     │
│                                 │
│   ┌───────────────────────────┐ │
│   │ Made good progress on     │ │
│   │ the auth flow...          │ │
│   └───────────────────────────┘ │
│                                 │
│   [🎤 Voice]    [😊😐😔 Mood]  │
│                                 │
│         [Done ✓]                │
│                                 │
└─────────────────────────────────┘
```

### 4.4 Apple Watch

```
┌───────────────┐     ┌───────────────┐     ┌───────────────┐
│  FOCUS MODE   │     │   BREATHE     │     │   HYDRATE     │
│               │     │               │     │               │
│    34:22      │     │     ○         │     │     💧        │
│   remaining   │     │   ○   ○      │     │               │
│               │     │     ○         │     │  [Yes]  [No]  │
│  [End Early]  │     │  Inhale...    │     │               │
└───────────────┘     └───────────────┘     └───────────────┘
```

Watch interactions are haptic-first:
- Focus start: 3 firm taps
- Breathe: rhythmic taps matching inhale/exhale
- Hydrate prompt: 2 gentle taps
- Cycle complete: success haptic pattern

---

## 5. Interaction Patterns

### The Ritual Bundle

The key UX decision: **all three ritual steps are ONE notification, ONE flow.** The user never gets separate "drink water" and "breathe" and "journal" notifications. It's always:

> "Your focus block is done. Time for your ritual." → [Breathe → Hydrate → Reflect] → Done.

This prevents notification fatigue and creates a Pavlovian association: notification = pleasant 5-minute break, not another demand.

### Progressive Disclosure

| User State | What They See |
|-----------|--------------|
| First launch | Onboarding (3 screens), then guided first cycle |
| Week 1 | Core features only (timer, ritual, timeline) |
| Week 2+ | Calendar integration prompt, widget suggestions |
| Week 4+ | AI summary unlock, paywall for Pro features |

### Gesture Language

| Gesture | Action |
|---------|--------|
| Tap timeline block | Start focus / view details |
| Long press block | Edit duration, delete |
| Swipe ritual step | Skip to next step |
| Pull down timeline | Refresh calendar events |
| Shake (Watch) | Quick-log water without opening app |

---

## 6. Accessibility

| Feature | Implementation |
|---------|---------------|
| VoiceOver | Full labels on all elements, timer announces remaining time |
| Dynamic Type | All text scales, layouts adapt |
| Reduce Motion | Breathe circle becomes opacity pulse, no sliding transitions |
| Color Blind | No color-only indicators, all states have icons/text |
| Haptics | Can be disabled independently, visual fallbacks |
| Bold Text | Supported via system setting |
| Switch Control | All interactive elements reachable |

---

## 7. Onboarding Flow

```
Screen 1: "Your day has a natural rhythm"
  → Illustration of ultradian cycle
  → "90 minutes of focus, then a reset."

Screen 2: "The ritual takes 5 minutes"
  → Breathe · Hydrate · Reflect
  → "One notification, three micro-habits."

Screen 3: "Set your rhythm"
  → Cycle duration picker (45 / 60 / 90 min)
  → Daily goal picker (2 / 3 / 4 / 5 cycles)
  → Hydration goal (auto-suggested based on weight if HealthKit allowed)

Screen 4: Permissions
  → Notifications (required for ritual prompts)
  → HealthKit (optional, for water sync)
  → Calendar (optional, for smart scheduling)
  → Focus mode (optional, for DND during sessions)

→ First cycle starts immediately after onboarding.
```

---

## 8. Sound Design

| Event | Sound | Character |
|-------|-------|-----------|
| Focus start | Soft chime (C major) | Intentional, like a meditation bell |
| Focus end | Warm tone (ascending) | Rewarding, not alarming |
| Breathe inhale | Subtle whoosh in | Natural, wind-like |
| Breathe exhale | Subtle whoosh out | Releasing |
| Hydration logged | Water drop | Satisfying, tactile |
| Journal saved | Soft click | Confirmation |
| Cycle complete | Gentle chord (resolved) | Accomplishment without fanfare |

All sounds optional, off by default if system is on silent.

---

## 9. Dark Mode

Full dark mode support with warm tones (not pure black):

- Background: #1A1A1A (not #000000 — easier on eyes)
- Cards: #2A2A2A with subtle border
- Primary green adjusts to lighter shade for contrast
- Timer ring glows subtly in dark mode
- Breathe circle has soft ambient glow

Auto-switches with system setting, or manual override in settings.
