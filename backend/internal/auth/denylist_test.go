package auth

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/rhythm-app/rhythm-api/internal/config"
)

// memDenylist is an in-memory Denylist for tests.
type memDenylist struct{ denied map[string]bool }

func newMemDenylist() *memDenylist { return &memDenylist{denied: map[string]bool{}} }

func (m *memDenylist) IsDenied(_ context.Context, jti string) (bool, error) {
	return m.denied[jti], nil
}

func (m *memDenylist) Deny(_ context.Context, jti string, _ time.Duration) error {
	m.denied[jti] = true
	return nil
}

func TestNoopDenylistNeverDenies(t *testing.T) {
	var d Denylist = NoopDenylist{}
	if err := d.Deny(context.Background(), "j", time.Minute); err != nil {
		t.Fatalf("Deny: %v", err)
	}
	if denied, _ := d.IsDenied(context.Background(), "j"); denied {
		t.Error("NoopDenylist must never report denied")
	}
}

// The core security property: a refresh token is single-use. Rotating it denies
// the presented token, and replaying it is rejected (reuse detection).
func TestHandleRefreshRotatesAndDetectsReuse(t *testing.T) {
	mem := newMemDenylist()
	s := NewService(config.Config{JWTSecret: "s", AppleBundleID: "b"}, WithDenylist(mem))
	refresh, err := issueToken(s.cfg.JWTSecret, "u1", TokenTypeRefresh, time.Hour, time.Now)
	if err != nil {
		t.Fatalf("issueToken: %v", err)
	}

	do := func() int {
		rec := httptest.NewRecorder()
		s.HandleRefresh(rec, httptest.NewRequest(http.MethodPost, "/auth/refresh",
			strings.NewReader(`{"refresh_token":"`+refresh+`"}`)))
		return rec.Code
	}

	// First use succeeds and revokes the presented token.
	if code := do(); code != http.StatusOK {
		t.Fatalf("first refresh: status = %d, want 200", code)
	}
	claims, err := validateToken(s.cfg.JWTSecret, refresh)
	if err != nil {
		t.Fatalf("validate: %v", err)
	}
	if denied, _ := mem.IsDenied(context.Background(), claims.ID); !denied {
		t.Fatal("presented refresh token should be denied after rotation")
	}

	// Replaying the same token is rejected.
	if code := do(); code != http.StatusUnauthorized {
		t.Fatalf("reused refresh: status = %d, want 401", code)
	}
}

// With the default NoopDenylist, refresh still works (no tracking).
func TestHandleRefreshWithNoopDenylistStillWorks(t *testing.T) {
	s := NewService(config.Config{JWTSecret: "s", AppleBundleID: "b"})
	refresh, _ := issueToken(s.cfg.JWTSecret, "u1", TokenTypeRefresh, time.Hour, time.Now)
	rec := httptest.NewRecorder()
	s.HandleRefresh(rec, httptest.NewRequest(http.MethodPost, "/auth/refresh",
		strings.NewReader(`{"refresh_token":"`+refresh+`"}`)))
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200", rec.Code)
	}
}
