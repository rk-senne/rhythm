#!/usr/bin/env bash
# Run the env-guarded integration tests against ephemeral PostgreSQL + Redis.
#
# Usage:
#   ./scripts/itest.sh            # run the full suite with real PG + Redis
#   ./scripts/itest.sh 'PgStore'  # restrict to a go test -run pattern
#
# Existing RHYTHM_TEST_DATABASE_URL / RHYTHM_TEST_REDIS_URL are honored (that
# service is used and not booted). Missing tooling => those tests simply skip.
set -euo pipefail

RUN="${1:-.}"
cd "$(dirname "$0")/.." # -> backend/

TMP="$(mktemp -d "${TMPDIR:-/tmp}/rhythm_itest.XXXXXX")"
PG_STARTED=""
REDIS_PID=""
cleanup() {
  if [ -n "$PG_STARTED" ]; then pg_ctl -D "$TMP/pgdata" -w stop >/dev/null 2>&1 || true; fi
  if [ -n "$REDIS_PID" ]; then kill "$REDIS_PID" >/dev/null 2>&1 || true; fi
  rm -rf "$TMP"
}
trap cleanup EXIT

# ---- PostgreSQL ----
if [ -z "${RHYTHM_TEST_DATABASE_URL:-}" ]; then
  PGBIN=""
  for c in /opt/homebrew/opt/postgresql@17/bin /opt/homebrew/opt/postgresql@15/bin \
           /usr/local/opt/postgresql@17/bin /usr/local/opt/postgresql@15/bin \
           /usr/lib/postgresql/*/bin; do
    if [ -x "$c/pg_ctl" ]; then PGBIN="$c"; break; fi
  done
  if [ -n "$PGBIN" ]; then
    export PATH="$PGBIN:$PATH"
    PGPORT="${PGTEST_PORT:-55432}"
    echo "Booting ephemeral Postgres ($PGBIN) on $PGPORT..."
    initdb -D "$TMP/pgdata" -U postgres --auth=trust -E UTF8 >/dev/null
    pg_ctl -D "$TMP/pgdata" -o "-p $PGPORT -k $TMP -c listen_addresses=127.0.0.1" -l "$TMP/pg.log" -w start
    PG_STARTED=1
    createdb -h 127.0.0.1 -p "$PGPORT" -U postgres rhythm_test
    export RHYTHM_TEST_DATABASE_URL="postgres://postgres@127.0.0.1:$PGPORT/rhythm_test?sslmode=disable"
  else
    echo "WARN: no PostgreSQL found; Postgres integration tests will skip." >&2
  fi
fi

# ---- Redis ----
if [ -z "${RHYTHM_TEST_REDIS_URL:-}" ]; then
  REDIS_SERVER=""
  for c in /opt/homebrew/opt/redis/bin/redis-server /usr/local/opt/redis/bin/redis-server; do
    if [ -x "$c" ]; then REDIS_SERVER="$c"; break; fi
  done
  if [ -z "$REDIS_SERVER" ] && command -v redis-server >/dev/null 2>&1; then
    REDIS_SERVER="$(command -v redis-server)"
  fi
  if [ -n "$REDIS_SERVER" ]; then
    REDISPORT="${REDISTEST_PORT:-63790}"
    REDIS_CLI="${REDIS_SERVER%server}cli"
    echo "Booting ephemeral Redis ($REDIS_SERVER) on $REDISPORT..."
    "$REDIS_SERVER" --port "$REDISPORT" --save "" --appendonly no >"$TMP/redis.log" 2>&1 &
    REDIS_PID=$!
    for _ in $(seq 1 50); do
      if [ -x "$REDIS_CLI" ] && "$REDIS_CLI" -p "$REDISPORT" ping >/dev/null 2>&1; then break; fi
      sleep 0.1
    done
    export RHYTHM_TEST_REDIS_URL="redis://127.0.0.1:$REDISPORT"
  else
    echo "WARN: no redis-server found; Redis integration tests will skip." >&2
  fi
fi

echo "Running tests (-run '$RUN')..."
go test ./... -run "$RUN" -v
