# Rhythm — Audit & Enhancements Report

**Document Version:** 1.0
**Date:** 31 July 2026
**Prepared by:** moonbase KND Council methodology (Analyst → Architect →
Implementer → QA/risk-gate → Reviewer, with Security/Architecture specialists).
**Doctrine:** evidence over claims; ask-don't-guess; verify before asserting.

---

## Executive Summary

Rhythm has **excellent, thorough strategy documentation** but the codebase is at
a **pre-MVP skeleton** stage (confirmed by `CRITICAL_NOTES.md`): no Xcode
project, no tests, silent error handling, and several unwired integrations. The
Go backend compiles but contained **real correctness and security bugs** that
would surface in production.

This session did two things:

1. **Audited** the backend and product against 2025–2026 market evidence (see
   `RESEARCH_FINDINGS_2026.md`).
2. **Implemented and verified** the highest-value, launch-blocking backend fixes
   plus one flagship product enhancement (gentle streaks), with automated tests.

**Verification at a glance (backend):** `go build ./...` ✅ · `go vet ./...` ✅ ·
`go test -race ./...` ✅ **32 tests passing** · `gofmt` clean.
**Verification (iOS):** `GentleStreak.swift` typechecks against the macOS SDK and
**10 XCTest cases pass** (verified in an isolated SwiftPM package).

---

## Part 1 — Backend Code Audit

Severity: 🔴 high (correctness/security) · 🟠 medium · 🟡 low.

| # | Area | Finding (evidence) | Sev | Status |
|---|------|--------------------|:---:|--------|
| 1 | Sync | **Deletes never synced.** `Change.DeletedAt` was decoded but never written by `Push` — the upsert omitted the column, so tombstones were silently dropped. (`internal/sync/handler.go`) | 🔴 | **Fixed** |
| 2 | Push | **Push worker never started.** `main.go` never constructed/ran `push.Worker`, so scheduled notifications were enqueued but never delivered. | 🔴 | **Fixed** |
| 3 | Auth | **Refresh accepted any valid token.** `HandleRefresh` validated the signature but not the token *type*, so a (short-lived) access token could be replayed to mint new access tokens. No token_type claim existed. (`internal/auth/auth.go`) | 🔴 | **Fixed** |
| 4 | Auth | **No HTTP timeouts.** Apple key fetch used `http.Get`; OpenAI used `http.DefaultClient` — both with no timeout (goroutine-hang / resource-exhaustion risk). | 🔴 | **Fixed** |
| 5 | AI | **No per-user rate limit or caching.** Every `/ai/weekly-summary` call hit OpenAI — a cost/DoS vector; identical requests regenerated the summary. | 🔴 | **Fixed** |
| 6 | Sync | **Client-clock cursor.** Pull filtered on the client-supplied `updated_at`; clock skew could make a device miss changes. Also no `LIMIT`/pagination. | 🟠 | **Fixed** |
| 7 | Sync | **Non-atomic push.** Each change was a separate `Exec`; a mid-batch failure left partial state (no transaction). | 🟠 | **Fixed** |
| 8 | Push | **Double-send race.** `ZRangeByScore` + `ZRem` were separate calls; two workers could read the same member and send twice. | 🟠 | **Fixed** |
| 9 | API | **No Content-Type + swallowed encode errors.** Handlers wrote JSON without `Content-Type` and ignored encode errors. | 🟡 | **Fixed** |
| 10 | Ops | **Shallow health check.** `/health` didn't verify DB/Redis; no readiness endpoint. No request timeout middleware; no `ReadHeaderTimeout` (slow-loris). | 🟡 | **Fixed** |
| 11 | Ops | **APNs sender is a stub** that logged and dropped. | 🟡 | **Fixed** — real `APNsSender` (HTTP/2, ES256 provider tokens, permanent/transient handling) behind the `Sender` seam; `LogSender` fallback when unconfigured. |
| 12 | Auth | **No token revocation/rotation.** Redis is available but unused for a denylist. | 🟠 | **Fixed** — refresh-token rotation with reuse detection via a Redis `Denylist` (revoke-on-rotate + `jti`); `NoopDenylist` default keeps it optional. |

---

## Part 2 — Enhancements Implemented (this session)

### Backend (Go) — verified with `go test -race` (32 tests)

- **`internal/web/respond.go`** *(new)* — shared `JSON`/`Error` helpers; correct
  `Content-Type`; encode errors are logged, not swallowed.
- **`internal/auth`** — split into `token.go` (typed access/refresh claims with
  `jti`), `applekeys.go` (TTL-cached Apple JWKS with a timeout client and
  stale-fallback), and `auth.go` (refresh now validates token type + rotates;
  middleware requires an *access* token). Tests: `token_test.go`,
  `applekeys_test.go`.
- **`internal/sync`** — introduced a `Store` interface (`store.go`, Postgres
  impl) so the handler is testable without a DB; `Push` is now transactional and
  persists tombstones; last-write-wins is enforced in SQL; `Pull` uses a
  **server-assigned cursor**, clamped `limit`, and a `has_more` flag. Tests:
  `handler_test.go`.
- **`migrations/002_sync_tombstones.{up,down}.sql`** *(new)* — adds `deleted_at`
  and `server_updated_at` (+ index) to `sync_changes`.
- **`internal/push`** — atomic Lua **dequeue** (removes the double-send race) and
  an injectable `Sender` (no more silent drop). Tests: `worker_test.go`.
- **`internal/ai`** — dependency-inverted into `JournalStore`, `Summarizer`,
  `RateLimiter`, `Cache` (`summary.go`); **cache-first, then per-user rate
  limit**, then generate; OpenAI call now uses a 30s-timeout client
  (`openai.go`); handler maps rate limits to **HTTP 429** (`handler.go`). Redis
  impls in `redis.go`. Tests: `summary_test.go`.
- **`cmd/server/main.go`** — starts the push worker; adds `/ready` (DB+Redis
  ping); per-route timeouts (auth/sync 15s, AI 35s); tighter rate limits on
  `/auth` (20/min) and `/ai` (10/min); `RequestID`; `ReadHeaderTimeout`;
  worker stops on shutdown via a cancelable root context.

### iOS (Swift) — verified: compiles + 10 XCTest cases pass

- **`ios/Rhythm/Core/GentleStreak.swift`** *(new)* — a dependency-free
  (Foundation-only) implementation of research rec #2: **rest days preserve the
  streak, a grace window absorbs occasional misses, lapses decay gradually
  (never a hard reset), and the streak can be earned back**. Includes
  non-punitive UI copy helpers aligned with the calm brand. Pure value type, so
  it drops into the app, Watch, and widget targets and is unit-testable in
  isolation.

> **iOS integration note:** `GentleStreak.swift` is verified as standalone Swift,
> but it is **not yet wired into a target** — the repo still has no Xcode project
> (see `CRITICAL_NOTES.md`). Add it to the app/Watch/Widget targets and feed it
> the user's completed-cycle and rest-day dates (e.g. from SwiftData) to render
> the streak.

---

## Part 3 — Product Gap Analysis (summary)

Full detail and sources in `RESEARCH_FINDINGS_2026.md`. The launch-critical
product gaps the research surfaced:

- **Onboarding** must deliver a first mini-cycle **before** any paywall/push
  prompt (biggest single retention lever).
- **Streaks** must be gentle (now available in code) — a top, cheap retention
  lever and a brand-safety requirement.
- **Free tier** should widen to 3 cycles/day and keep a basic **free Watch**.
- **Live Activity** should span the whole cycle (retention + organic content).
- **Positioning** must lead with *ultradian rhythm + transition ritual*, never
  "Pomodoro alternative."
- **Monetization** assumptions need correcting: plan for **2–3% conversion**,
  delay the trial to after 3+ cycles, and defer the Team tier.

---

## Part 4 — Prioritized Backlog (not yet implemented)

**MVP-blocking (product/UX — needs the Xcode project first):**
1. First-value onboarding (2-min mini-cycle before paywall/push).
2. Full-cycle Live Activity + home-screen widget (streak + next cycle).
3. Wire `GentleStreak` into the app/Watch/Widget targets.
4. Free tier → 3 cycles/day; keep basic Watch free.
5. Crash monitoring (Sentry/Crashlytics) from day one.
6. Replace remaining silent `try?` paths with user-facing error states.

**Backend (pre-launch hardening):**
7. ✅ **Done:** real APNs HTTP/2 transport (`push.APNsSender` + ES256
   `TokenProvider`) behind the `push.Sender` seam, config-gated with a
   `LogSender` fallback; permanent (410/400/403) vs transient (5xx/429) handling.
8. ✅ **Done:** refresh-token denylist in Redis with rotation + reuse detection
   (`auth.Denylist` interface; `NoopDenylist` default, `RedisDenylist` wired in
   `main.go`; unit + Redis integration tested).
9. ✅ **Done:** `PgStore` integration tests + an authenticated push→pull HTTP
   e2e now run against an ephemeral Postgres (`make itest`, env-guarded so normal
   CI stays hermetic). Still TODO: Redis limiter/cache integration coverage.

**Post-launch growth:**
10. Triggered 7-day Pro trial (after 3+ cycles) + annual-first paywall.
11. Apple featuring + Design Award submission.
12. "Focus Wrapped" shareable recaps.
13. Churn plumbing: billing grace period, pause-instead-of-cancel, win-back.

---

## Part 5 — Risk Gate & Rollback

- **Risk level:** LOW for the backend changes — all changes are covered by unit
  tests, build/vet/`-race` are green, and no production infrastructure was
  touched. The new migration `002` is additive (nullable column + new
  server-timestamp column with a default) and reversible via the provided
  `.down.sql`.
- **Behavioral change to note:** the auth middleware now **requires an access
  token** and the refresh endpoint **rejects non-refresh tokens**. Any client or
  test previously relying on the old permissive behavior must send the correct
  token type. Tokens now also include `token_type` and `jti` claims.
- **Rollback:** revert the commit and run `migrate down 1` to drop the added
  columns. No data is destroyed by the forward migration.
- **Not verified here:** end-to-end behavior against a live Postgres/Redis/APNs
  and the full iOS build (no Xcode project exists yet). These are called out
  above as backlog items.
