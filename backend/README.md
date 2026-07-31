# Rhythm Backend

## Local Development

### Prerequisites
- Go 1.22+
- Docker & Docker Compose

### Setup
```bash
# Start Postgres + Redis
docker compose up -d

# Copy env vars
cp .env.example .env

# Download dependencies
go mod tidy

# Run server (auto-runs migrations)
go run ./cmd/server
```

### Verify
```bash
curl http://localhost:8080/health
# → ok
```

### Endpoints
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | /health | No | Liveness check |
| GET | /ready | No | Readiness check (verifies Postgres + Redis) |
| POST | /auth/apple | No | Exchange Apple identity token for JWT |
| POST | /auth/refresh | No | Refresh access token (refresh-token only) |
| POST | /sync/push | Yes | Push local changes to server |
| GET | /sync/pull?since=RFC3339 | Yes | Pull changes since server cursor |
| GET | /ai/weekly-summary | Yes | AI weekly journal summary (rate-limited + cached) |


## Testing

```bash
make test     # fast, hermetic unit tests (no external services)
make itest    # integration tests against an ephemeral Postgres
make vet      # go vet
```

- **Unit tests** cover handlers, auth (token types, Apple-key cache), the AI
  cache/rate-limit logic, and the push worker using in-memory fakes — no DB or
  network required. Integration tests are skipped automatically.
- **Integration tests** validate real infrastructure the fakes cannot:
  - `internal/sync/pgstore_integration_test.go` — real `PgStore` SQL (tombstone
    propagation, the last-write-wins `ON CONFLICT` guard, the server-assigned
    pull cursor) plus an authenticated push→pull HTTP round-trip through the chi
    router + auth middleware (needs `RHYTHM_TEST_DATABASE_URL`).
  - `internal/ai/redis_integration_test.go` — real Redis rate limiter + summary
    cache (INCR/EXPIRE/TTL/GET/SET) and the service-level cache-hit / rate-limit
    behavior (needs `RHYTHM_TEST_REDIS_URL`).

  `make itest` boots throwaway Postgres + Redis (via `brew`), runs the suite, and
  tears them down. Both are skipped automatically when their env var is unset.
