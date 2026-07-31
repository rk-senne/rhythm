package sync

// Real-database integration tests. These are SKIPPED unless
// RHYTHM_TEST_DATABASE_URL points at a throwaway Postgres, so `go test ./...`
// stays hermetic in normal/CI runs. Run locally with an ephemeral DB via
// `make itest` (see backend/Makefile).
//
// They validate the actual SQL in PgStore that unit tests (which use fakes)
// cannot: tombstone persistence, the last-write-wins ON CONFLICT guard, and the
// server-assigned cursor that makes pull resilient to client clock skew.

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/golang-jwt/jwt/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/rhythm-app/rhythm-api/internal/auth"
	"github.com/rhythm-app/rhythm-api/internal/config"
)

// integrationDB connects to the test database, rebuilds a fresh schema (matching
// migrations 001+002), seeds a user, and returns the pool. Skips if unset.
func integrationDB(t *testing.T) *pgxpool.Pool {
	t.Helper()
	url := os.Getenv("RHYTHM_TEST_DATABASE_URL")
	if url == "" {
		t.Skip("RHYTHM_TEST_DATABASE_URL not set; skipping Postgres integration test")
	}
	ctx := context.Background()
	pool, err := pgxpool.New(ctx, url)
	if err != nil {
		t.Fatalf("connect: %v", err)
	}
	t.Cleanup(pool.Close)

	const schema = `
DROP TABLE IF EXISTS sync_changes;
DROP TABLE IF EXISTS users;
CREATE TABLE users (
    id TEXT PRIMARY KEY,
    apple_sub TEXT UNIQUE NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TABLE sync_changes (
    user_id TEXT NOT NULL REFERENCES users(id),
    table_name TEXT NOT NULL,
    record_id TEXT NOT NULL,
    data JSONB NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    server_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, table_name, record_id)
);
CREATE INDEX idx_sync_changes_server_updated ON sync_changes(user_id, server_updated_at);`

	if _, err := pool.Exec(ctx, schema); err != nil {
		t.Fatalf("create schema: %v", err)
	}
	if _, err := pool.Exec(ctx, `INSERT INTO users (id, apple_sub) VALUES ($1, $2)`, "u1", "apple-u1"); err != nil {
		t.Fatalf("seed user: %v", err)
	}
	return pool
}

func TestPgStoreApplyAndPull(t *testing.T) {
	pool := integrationDB(t)
	store := NewPgStore(pool)
	ctx := context.Background()

	err := store.ApplyChanges(ctx, "u1", []Change{
		{Table: "cycles", ID: "C1", Data: json.RawMessage(`{"v":1}`), UpdatedAt: time.Now().UTC()},
	})
	if err != nil {
		t.Fatalf("apply: %v", err)
	}

	got, err := store.ChangesSince(ctx, "u1", time.Time{}, 100)
	if err != nil {
		t.Fatalf("pull: %v", err)
	}
	if len(got) != 1 || got[0].ID != "C1" {
		t.Fatalf("pull returned %+v, want one change C1", got)
	}
	if got[0].ServerUpdatedAt.IsZero() {
		t.Error("server_updated_at should be assigned by the DB")
	}
	if got[0].DeletedAt != nil {
		t.Error("change should not be a tombstone")
	}
}

func TestPgStoreTombstonePropagates(t *testing.T) {
	pool := integrationDB(t)
	store := NewPgStore(pool)
	ctx := context.Background()

	del := time.Now().UTC()
	if err := store.ApplyChanges(ctx, "u1", []Change{
		{Table: "cycles", ID: "C1", Data: json.RawMessage(`{}`), UpdatedAt: del, DeletedAt: &del},
	}); err != nil {
		t.Fatalf("apply: %v", err)
	}

	got, _ := store.ChangesSince(ctx, "u1", time.Time{}, 100)
	if len(got) != 1 || got[0].DeletedAt == nil {
		t.Fatalf("delete tombstone did not propagate: %+v", got)
	}
}

func TestPgStoreLastWriteWins(t *testing.T) {
	pool := integrationDB(t)
	store := NewPgStore(pool)
	ctx := context.Background()
	base := time.Now().UTC()

	apply := func(v int, at time.Time) {
		if err := store.ApplyChanges(ctx, "u1", []Change{
			{Table: "t", ID: "1", Data: json.RawMessage(fmt.Sprintf(`{"v":%d}`, v)), UpdatedAt: at},
		}); err != nil {
			t.Fatalf("apply v=%d: %v", v, err)
		}
	}
	readV := func() int {
		got, _ := store.ChangesSince(ctx, "u1", time.Time{}, 100)
		if len(got) != 1 {
			t.Fatalf("want 1 row, got %d", len(got))
		}
		var p struct{ V int }
		_ = json.Unmarshal(got[0].Data, &p)
		return p.V
	}

	apply(1, base)
	apply(0, base.Add(-time.Hour)) // older -> must NOT win
	if v := readV(); v != 1 {
		t.Errorf("older write won (v=%d); LWW guard broken", v)
	}
	apply(2, base.Add(time.Hour)) // newer -> must win
	if v := readV(); v != 2 {
		t.Errorf("newer write did not win (v=%d)", v)
	}
}

func TestPgStorePaginationByServerCursor(t *testing.T) {
	pool := integrationDB(t)
	store := NewPgStore(pool)
	ctx := context.Background()

	for i := 0; i < 5; i++ {
		if err := store.ApplyChanges(ctx, "u1", []Change{
			{Table: "t", ID: fmt.Sprintf("R%d", i), Data: json.RawMessage(`{}`), UpdatedAt: time.Now().UTC()},
		}); err != nil {
			t.Fatalf("apply %d: %v", i, err)
		}
		time.Sleep(2 * time.Millisecond) // distinct server_updated_at for stable ordering
	}

	page1, _ := store.ChangesSince(ctx, "u1", time.Time{}, 2)
	if len(page1) != 2 {
		t.Fatalf("page1 = %d, want 2", len(page1))
	}
	cursor := page1[len(page1)-1].ServerUpdatedAt
	page2, _ := store.ChangesSince(ctx, "u1", cursor, 2)
	if len(page2) != 2 {
		t.Fatalf("page2 = %d, want 2", len(page2))
	}
	seen := map[string]bool{page1[0].ID: true, page1[1].ID: true}
	if seen[page2[0].ID] || seen[page2[1].ID] {
		t.Errorf("pagination overlap between pages: p1=%v p2=%v", ids(page1), ids(page2))
	}
}

func TestPgStoreServerCursorIgnoresClientClock(t *testing.T) {
	pool := integrationDB(t)
	store := NewPgStore(pool)
	ctx := context.Background()

	// Client clock is 10 days behind; server_updated_at is still now().
	past := time.Now().Add(-240 * time.Hour).UTC()
	if err := store.ApplyChanges(ctx, "u1", []Change{
		{Table: "t", ID: "stale-clock", Data: json.RawMessage(`{}`), UpdatedAt: past},
	}); err != nil {
		t.Fatalf("apply: %v", err)
	}

	// A pull since "an hour ago" (server time) must still see it.
	got, _ := store.ChangesSince(ctx, "u1", time.Now().Add(-time.Hour).UTC(), 100)
	found := false
	for _, c := range got {
		if c.ID == "stale-clock" {
			found = true
		}
	}
	if !found {
		t.Error("server cursor should return the change despite a stale client clock")
	}
}

// TestSyncE2EAuthenticatedPushThenPull exercises the full authenticated stack:
// chi router + auth middleware + PgStore against the real DB.
func TestSyncE2EAuthenticatedPushThenPull(t *testing.T) {
	pool := integrationDB(t)

	const secret = "e2e-secret"
	authSvc := auth.NewService(config.Config{JWTSecret: secret, AppleBundleID: "com.rhythm.app"})
	h := NewHandler(NewPgStore(pool))

	r := chi.NewRouter()
	r.Route("/sync", func(r chi.Router) {
		r.Use(authSvc.Middleware)
		r.Post("/push", h.Push)
		r.Get("/pull", h.Pull)
	})
	srv := httptest.NewServer(r)
	defer srv.Close()

	token := mintAccessToken(t, secret, "u1")

	// Push using the exact iOS wire format.
	pushBody := `{"changes":[{"table":"cycles","id":"C1","data":{"focus_duration":5400},"updated_at":"2026-07-31T10:00:00Z"}]}`
	pushReq, _ := http.NewRequest(http.MethodPost, srv.URL+"/sync/push", strings.NewReader(pushBody))
	pushReq.Header.Set("Content-Type", "application/json")
	pushReq.Header.Set("Authorization", "Bearer "+token)
	pushResp, err := http.DefaultClient.Do(pushReq)
	if err != nil {
		t.Fatalf("push: %v", err)
	}
	if pushResp.StatusCode != http.StatusOK {
		b, _ := io.ReadAll(pushResp.Body)
		t.Fatalf("push status = %d: %s", pushResp.StatusCode, b)
	}
	pushResp.Body.Close()

	// Pull it back.
	pullReq, _ := http.NewRequest(http.MethodGet, srv.URL+"/sync/pull?since=2000-01-01T00:00:00Z", nil)
	pullReq.Header.Set("Authorization", "Bearer "+token)
	pullResp, err := http.DefaultClient.Do(pullReq)
	if err != nil {
		t.Fatalf("pull: %v", err)
	}
	defer pullResp.Body.Close()
	if pullResp.StatusCode != http.StatusOK {
		t.Fatalf("pull status = %d", pullResp.StatusCode)
	}
	var pull PullResponse
	if err := json.NewDecoder(pullResp.Body).Decode(&pull); err != nil {
		t.Fatalf("decode pull: %v", err)
	}
	if len(pull.Changes) != 1 || pull.Changes[0].ID != "C1" {
		t.Fatalf("pull did not return the pushed change: %+v", pull.Changes)
	}

	// Missing token must be rejected.
	noAuth, _ := http.NewRequest(http.MethodGet, srv.URL+"/sync/pull", nil)
	noAuthResp, err := http.DefaultClient.Do(noAuth)
	if err != nil {
		t.Fatalf("no-auth pull: %v", err)
	}
	if noAuthResp.StatusCode != http.StatusUnauthorized {
		t.Errorf("no-token pull status = %d, want 401", noAuthResp.StatusCode)
	}
	noAuthResp.Body.Close()
}

func mintAccessToken(t *testing.T, secret, userID string) string {
	t.Helper()
	claims := jwt.MapClaims{
		"sub":        userID,
		"token_type": "access",
		"iss":        "rhythm-api",
		"iat":        time.Now().Unix(),
		"exp":        time.Now().Add(time.Hour).Unix(),
	}
	signed, err := jwt.NewWithClaims(jwt.SigningMethodHS256, claims).SignedString([]byte(secret))
	if err != nil {
		t.Fatalf("mint token: %v", err)
	}
	return signed
}

func ids(changes []Change) []string {
	out := make([]string, len(changes))
	for i, c := range changes {
		out[i] = c.ID
	}
	return out
}
