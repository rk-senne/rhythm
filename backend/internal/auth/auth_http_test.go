package auth

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/rhythm-app/rhythm-api/internal/config"
)

func testService() *Service {
	return NewService(config.Config{
		JWTSecret:     "contract-test-secret",
		AppleBundleID: "com.rhythm.app",
	})
}

// The iOS AuthClient POSTs {"refresh_token": "..."} and decodes
// {access_token, refresh_token, expires_in}. This locks that shape.
func TestHandleRefreshReturnsIOSTokenShape(t *testing.T) {
	s := testService()
	refresh, err := issueToken(s.cfg.JWTSecret, "user-1", TokenTypeRefresh, time.Hour, time.Now)
	if err != nil {
		t.Fatalf("issueToken: %v", err)
	}

	req := httptest.NewRequest(http.MethodPost, "/auth/refresh",
		strings.NewReader(`{"refresh_token":"`+refresh+`"}`))
	rec := httptest.NewRecorder()
	s.HandleRefresh(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200; body=%s", rec.Code, rec.Body.String())
	}
	if ct := rec.Header().Get("Content-Type"); !strings.Contains(ct, "application/json") {
		t.Errorf("Content-Type = %q, want application/json", ct)
	}

	var resp struct {
		AccessToken  string `json:"access_token"`
		RefreshToken string `json:"refresh_token"`
		ExpiresIn    int    `json:"expires_in"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if resp.AccessToken == "" {
		t.Error("missing access_token")
	}
	if resp.RefreshToken == "" {
		t.Error("missing rotated refresh_token")
	}
	if resp.ExpiresIn <= 0 {
		t.Errorf("expires_in = %d, want > 0", resp.ExpiresIn)
	}
}

// Regression for the original vulnerability: an access token must not be
// accepted at the refresh endpoint.
func TestHandleRefreshRejectsAccessToken(t *testing.T) {
	s := testService()
	access, _ := issueToken(s.cfg.JWTSecret, "user-1", TokenTypeAccess, time.Hour, time.Now)
	req := httptest.NewRequest(http.MethodPost, "/auth/refresh",
		strings.NewReader(`{"refresh_token":"`+access+`"}`))
	rec := httptest.NewRecorder()
	s.HandleRefresh(rec, req)
	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want 401 (access token must be rejected)", rec.Code)
	}
}

func TestHandleRefreshRejectsGarbageAndMalformed(t *testing.T) {
	s := testService()

	rec := httptest.NewRecorder()
	s.HandleRefresh(rec, httptest.NewRequest(http.MethodPost, "/auth/refresh",
		strings.NewReader(`{"refresh_token":"not-a-jwt"}`)))
	if rec.Code != http.StatusUnauthorized {
		t.Errorf("garbage token: status = %d, want 401", rec.Code)
	}

	rec2 := httptest.NewRecorder()
	s.HandleRefresh(rec2, httptest.NewRequest(http.MethodPost, "/auth/refresh",
		strings.NewReader(`{bad json`)))
	if rec2.Code != http.StatusBadRequest {
		t.Errorf("malformed json: status = %d, want 400", rec2.Code)
	}
}

// The middleware (used by /sync and /ai) must accept access tokens and reject
// refresh tokens and missing headers.
func TestMiddlewareEnforcesAccessToken(t *testing.T) {
	s := testService()
	access, _ := issueToken(s.cfg.JWTSecret, "user-1", TokenTypeAccess, time.Hour, time.Now)
	refresh, _ := issueToken(s.cfg.JWTSecret, "user-1", TokenTypeRefresh, time.Hour, time.Now)

	var gotUserID string
	protected := s.Middleware(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotUserID, _ = r.Context().Value(UserIDKey).(string)
		w.WriteHeader(http.StatusOK)
	}))

	do := func(authz string) int {
		req := httptest.NewRequest(http.MethodGet, "/sync/pull", nil)
		if authz != "" {
			req.Header.Set("Authorization", authz)
		}
		rec := httptest.NewRecorder()
		protected.ServeHTTP(rec, req)
		return rec.Code
	}

	if code := do("Bearer " + access); code != http.StatusOK {
		t.Errorf("access token: status = %d, want 200", code)
	}
	if gotUserID != "user-1" {
		t.Errorf("user id = %q, want user-1", gotUserID)
	}
	if code := do("Bearer " + refresh); code != http.StatusUnauthorized {
		t.Errorf("refresh token: status = %d, want 401", code)
	}
	if code := do(""); code != http.StatusUnauthorized {
		t.Errorf("no auth: status = %d, want 401", code)
	}
}
