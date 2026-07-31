# Rhythm — Software Quality Review

**Date:** 31 July 2026
**Method:** Audited against the software-engineering canon in the moonbase
research library (`/moonbase/research`) — principles cited to their source.
**Scope:** Go backend (fully verified) + iOS (observations; verified builds/tests
in prior rounds). Every claim below is backed by code and by test/tool output
cited in §6.

> Sources referenced: **Kleppmann**, *Designing Data-Intensive Applications*
> (DDIA); **Ousterhout**, *A Philosophy of Software Design* (APoSD);
> **Martin**, *Clean Architecture*, *Clean Code*, *The Clean Coder*;
> **Hunt & Thomas**, *The Pragmatic Programmer*; **Brown**, *The C4 Model*.

---

## 1. Scorecard

| Quality attribute | Rating | Basis |
|-------------------|:------:|-------|
| Modularity / dependency direction | ★★★★☆ | DIP via interfaces; DB/Redis/OpenAI are plugins |
| Correctness (no data loss) | ★★★★☆ | delete-sync fixed; push retry added; clock-skew clamped |
| Testability & coverage | ★★★★★ | 38 hermetic + 13 integration tests; deep-module seams |
| Operability | ★★★★☆ | timeouts, `/ready`, tunable cost caps, structured logs |
| Reliability under failure | ★★★☆☆ | retries + atomic dequeue; LWW & fixed-window are accepted tradeoffs |
| Automated quality gate | ★★★★★ | CI: build/vet/gofmt/race/vuln + real-service integration + iOS |

---

## 2. What already holds up well (with citations)

**Dependency Inversion — business rules depend on abstractions; the DB and
frameworks are plugins.** *(Martin, Clean Architecture — "the database and the UI
depend on the business rules… never mention the DB.")* The backend defines
`sync.Store`, `ai.JournalStore`, `ai.Summarizer`, `ai.RateLimiter`, `ai.Cache`,
and `push.Sender` interfaces; handlers/services never touch `pgx`/`redis`/OpenAI
directly. This is exactly the plugin arrangement Martin advocates, and it is what
makes the code unit-testable without live infrastructure.

**Deep modules with simple interfaces.** *(Ousterhout, APoSD.)*
`SummaryService.GenerateWeeklySummary(userID)` is a one-method interface hiding a
multi-step pipeline (cache → rate-limit → fetch → summarize → cache). The
complexity is *inside* the module, not leaked to callers.

**"Define errors out of existence."** *(Ousterhout, APoSD.)* `parseSince` and
`parseLimit` turn malformed input into safe defaults rather than error paths the
caller must handle.

**DRY / one voice for responses.** *(Hunt & Thomas, Pragmatic Programmer; Martin,
Clean Code.)* `internal/web` centralizes JSON/error responses, sets
`Content-Type`, and **logs** encode failures instead of swallowing them.

**Test pyramid.** *(Martin, Clean Coder.)* Many fast unit tests at the base, a
middle layer of real-DB/Redis integration tests, and an authenticated push→pull
e2e at the top.

---

## 3. Findings fixed this round (principle → issue → fix → test)

### Fix A — Wall-clock last-write-wins is unsafe under clock skew
*(Kleppmann, DDIA Ch.5, "Last write wins (discarding concurrent writes)": LWW
achieves convergence but sacrifices durability, and ordering by a physical clock
is dangerous when clocks are skewed.)*

- **Issue:** `sync` conflict resolution is LWW keyed on the **client's**
  `updated_at`. A device with a fast/wrong clock could stamp a far-future time
  and then **win every future conflict permanently**, blocking legitimate edits.
- **Fix:** `clampFutureTimestamps()` caps any client `updated_at`/`deleted_at`
  more than `maxClockSkew` (24h) ahead of the server to server-now — bounding the
  blast radius of a bad clock **without discarding the write**. (`internal/sync/handler.go`)
- **Tests:** `TestClampFutureTimestamps`, `TestPushClampsFutureClientClock`.

### Fix B — Cost-control knobs were inline magic numbers
*(Ousterhout, APoSD & Martin, Clean Code — name constants; make policy visible.
Operability: cost caps should be tunable without a code change.)*

- **Issue:** the AI rate limit (`5`) and window (`time.Hour`) were hard-coded at
  the call site in `main.go`; the 24h cache TTL was an inline literal.
- **Fix:** `config.AISummaryRateLimit` / `AISummaryWindow` (env-tunable defaults),
  and a named `defaultCacheTTL` constant. `main.go` now wires the config values.

### Fix C — Failed push deliveries were silently dropped
*(Martin, Clean Coder — "First, do no harm to function": no data / message loss.)*

- **Issue:** after the atomic dequeue, `deliver()` only *logged* a send failure —
  the notification was lost (at-most-once).
- **Fix:** `deliver()` now returns the failed notifications and `processDue()`
  re-enqueues them (`retryDelay = 60s`), giving at-least-once retry; malformed
  payloads are dropped (they can never succeed), not retried forever.
- **Tests:** `TestDeliverReturnsFailedSendsForRetry`, `TestDeliverSkipsMalformedAndSendsValid`.

### Quality gate — "Done means done"
*(Martin, Clean Coder — "Done means all code written, all tests pass"; automated
tests are the definition of done.)* Added `.github/workflows/ci.yml`:
- **backend (hermetic):** build, `vet`, `gofmt` clean, `-race` tests, `govulncheck`.
- **backend-integration:** Postgres 17 + Redis 7 **service containers** run the
  real-DB/Redis suite.
- **iOS:** XcodeGen + `xcodebuild test` on a simulator.

---

## 4. Accepted tradeoffs & known limitations (stated honestly)

Per Ousterhout, design decisions should be explicit, not accidental:

1. **LWW discards truly concurrent writes.** *(DDIA Ch.5.)* For a
   single-user/multi-device personal app, genuine concurrent edits to the same
   record are rare, so LWW is an acceptable, simple choice. Fix A hardens it
   against clock skew. A per-field merge or version-vector scheme is the
   documented upgrade path if multi-device conflicts become common.
2. **Fixed-window rate limit** allows up to ~2× at a window boundary. Acceptable
   for a cost cap on a weekly summary; a sliding window is the upgrade if abuse
   appears.
3. **APNs transport is implemented** (`push.APNsSender`: HTTP/2 JSON, ES256
   provider-token auth, permanent-vs-transient failure handling), config-gated
   with a `LogSender` fallback when APNs env vars are unset. Real Apple creds + a
   device token are still needed to exercise a live send in production.
4. **iOS sync loop is closed:** `SyncApplier` applies pulled changes into
   SwiftData (upsert by id + tombstone delete, unknown-table skip), `SyncClient.pull`
   invokes it, and **cycle, journal, and hydration** are all pushed on completion.
   A failed local save now surfaces a user-facing error alert (no silent loss).

---

## 5. Prioritized remaining recommendations

1. ✅ **Done:** real APNs HTTP/2 `Sender` with ES256 provider tokens and
   permanent-vs-transient retry semantics (config-gated, `LogSender` fallback).
2. ✅ **Done:** `SyncApplier` applies pulled changes into SwiftData and
   cycle + journal + hydration are pushed on completion (verified against an
   in-memory store and via TCA tests).
3. ✅ **Done:** refresh-token rotation with reuse detection via a Redis
   `Denylist` (revoke-on-rotate; a replayed refresh token is rejected). Verified
   with an in-memory fake and against real Redis.
4. Consider per-field conflict resolution if analytics show multi-device
   conflicts.

---

## 6. Verification evidence

- **Hermetic backend:** `go build ./...` ✅ · `go vet ./...` ✅ ·
  `gofmt -l` clean ✅ · `go test -race ./...` ✅ **38 passing**.
- **Integration (`make itest`, ephemeral Postgres + Redis):** **13 passing**
  (6 Postgres SQL/e2e + 7 Redis) — validates LWW guard, tombstones, server
  cursor, rate limiter, cache.
- **New this round:** `TestClampFutureTimestamps`, `TestPushClampsFutureClientClock`,
  `TestDeliverReturnsFailedSendsForRetry` all pass.
- **CI:** `.github/workflows/ci.yml` validated (3 jobs: backend,
  backend-integration, ios).
- **iOS (prior rounds):** app compiles (4-target XcodeGen project); 15 tests
  pass on the iPhone 16 simulator.
