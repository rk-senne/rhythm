.PHONY: build run test vet itest

build:
	go build ./...

run:
	go run ./cmd/server

# Fast, hermetic unit tests (integration tests skip without a DB).
test:
	go test ./...

vet:
	go vet ./...

# Integration tests against ephemeral Postgres + Redis (real SQL: tombstones,
# last-write-wins, server cursor, authenticated push->pull e2e; real Redis:
# rate limiter + summary cache). Uses a local PostgreSQL/Redis (brew) or the
# RHYTHM_TEST_DATABASE_URL / RHYTHM_TEST_REDIS_URL env vars.
itest:
	./scripts/itest.sh
