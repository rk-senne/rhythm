# Rhythm — Deployment & Manual Finish Checklist

**Date:** 31 July 2026

Everything in the codebase that can be built and tested headlessly is done and
green (backend ~65 tests + CI gate; iOS 32 tests). What remains **requires your
accounts, credentials, physical devices, or design assets** — this document is
the exact list, in order.

Legend: 🔑 needs an account/credential · 📱 needs a device · 🎨 needs a designer/translator

---

## 1. Accounts to create 🔑
- **Apple Developer Program** ($99/yr) — app IDs, signing, App Store Connect.
- **RevenueCat** — subscription management (free under $2.5K MTR).
- **Backend host** — Fly.io (a `Dockerfile` + `fly.toml` already exist).
- **Managed data** — Neon (Postgres) + Upstash (Redis), or equivalents.
- **OpenAI** — API key for the weekly-summary endpoint.
- *(Optional)* Analytics/crash — TelemetryDeck / PostHog and Sentry.

## 2. Apple setup 🔑
- Create the App ID `com.rhythm.app` (change the prefix everywhere — see §4).
- Enable capabilities: **HealthKit, Push Notifications, App Groups
  (`group.com.rhythm.app`), Sign in with Apple, Background Modes**.
- **APNs auth key**: create a `.p8` key; note the **Key ID** and your **Team ID**.
- **Family Controls / ManagedSettings** (used by `FocusModeClient`) requires a
  **special entitlement request** to Apple — apply early, it can take time.
- Create matching **provisioning profiles** (or use automatic signing).

## 3. Xcode project config
- In `ios/Rhythm/project.yml` set `DEVELOPMENT_TEAM` and replace the
  `com.rhythm.app` bundle-ID prefix; run `xcodegen generate`.
- 🎨 Add a real **App Icon** (1024px) to `Config/Assets.xcassets/AppIcon`.
- Add the Family Controls entitlement to `Config/Rhythm.entitlements` once granted.

## 4. Secrets & config
Backend (`backend/.env` — see `.env.example`):
`DATABASE_URL`, `REDIS_URL`, `JWT_SECRET` (32+ random bytes), `APPLE_TEAM_ID`,
`APPLE_BUNDLE_ID`, `APNS_KEY_ID`, `APNS_KEY_P8` (PEM contents), `APNS_TOPIC`,
`APNS_PRODUCTION`, `OPENAI_API_KEY`, optional `AI_SUMMARY_RATE_LIMIT`/`_WINDOW`.

iOS:
- 🔑 RevenueCat key in `Core/Clients/PaywallClient.swift` (replace
  `your_revenuecat_api_key`).
- Replace `http://localhost:8080` in `Core/Clients/{Sync,Auth}Client.swift` with
  your deployed API URL (consider a build-config value).

## 5. Deploy the backend
```bash
cd backend
fly launch          # first time; uses Dockerfile + fly.toml
fly secrets set DATABASE_URL=... REDIS_URL=... JWT_SECRET=... APPLE_TEAM_ID=... \
                APPLE_BUNDLE_ID=... APNS_KEY_ID=... APNS_TOPIC=... OPENAI_API_KEY=...
fly deploy
curl https://<your-app>.fly.dev/ready     # -> {"status":"ok"} when DB+Redis reachable
```
Migrations run automatically on boot (`storage.RunMigrations`).

## 6. App Store Connect 🔑
- Create the app record; set metadata from `docs/APP_STORE_LISTING.md`.
- Create **subscriptions**: Pro monthly ($4.99) + annual ($39.99) in a group.
- Configure a **StoreKit configuration file** in Xcode for local purchase testing.
- Fill **privacy nutrition labels** (HealthKit data stays on-device / in your DB;
  journals are user content; no tracking SDKs unless you add them).

## 7. Analytics / crash (optional)
- Wire `TelemetryClient.liveValue.track` (in `Core/Telemetry/TelemetryClient.swift`)
  to a real SDK — call sites and events are already instrumented
  (`cycle_completed`, `paywall_shown`, `onboarding_completed`). Keep PII out.
- Add Sentry/Crashlytics for crash reporting.

## 8. On-device verification 📱 (can't be done in a simulator/CI)
- [ ] Sign in with Apple end-to-end (tokens land in Keychain).
- [ ] HealthKit authorization + water logged on ritual complete.
- [ ] A real APNs push is delivered (once a device-token registration + a
      producer are added — see below).
- [ ] StoreKit purchase + restore flips `isPro`; paywall gating behaves.
- [ ] Two-device sync: complete a cycle on device A → appears on device B.

## 9. Known follow-ups (code, but need device/SDK to be meaningful)
- **Server push is delivery-only:** the APNs worker + retry are built and tested,
  but there's **no device-token registration endpoint and no producer** enqueuing
  notifications. MVP uses **local** notifications (`NotificationClient`); add the
  server side only when you need remote/team triggers.
- **Watch ↔ iPhone** (`WatchConnectivity`) not implemented; the watch runs
  independently.
- **Calendar (EventKit)** and **"Focus Wrapped" recaps** are post-MVP.
- 🎨 **Localization** (String Catalog + translators) for non-English markets.
