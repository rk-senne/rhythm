package sync

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/rhythm-app/rhythm-api/internal/auth"
)

type fakeStore struct {
	applied    []Change
	applyErr   error
	pullResult []Change
	pullErr    error
	lastSince  time.Time
	lastLimit  int
}

func (f *fakeStore) ApplyChanges(_ context.Context, _ string, changes []Change) error {
	if f.applyErr != nil {
		return f.applyErr
	}
	f.applied = append(f.applied, changes...)
	return nil
}

func (f *fakeStore) ChangesSince(_ context.Context, _ string, since time.Time, limit int) ([]Change, error) {
	f.lastSince = since
	f.lastLimit = limit
	return f.pullResult, f.pullErr
}

func withUser(r *http.Request, userID string) *http.Request {
	return r.WithContext(context.WithValue(r.Context(), auth.UserIDKey, userID))
}

func TestPushPersistsDeletes(t *testing.T) {
	store := &fakeStore{}
	h := NewHandler(store)

	deletedAt := time.Now().UTC()
	body, _ := json.Marshal(PushRequest{Changes: []Change{
		{Table: "cycles", ID: "c1", Data: json.RawMessage(`{"x":1}`), UpdatedAt: deletedAt, DeletedAt: &deletedAt},
	}})
	req := withUser(httptest.NewRequest(http.MethodPost, "/sync/push", strings.NewReader(string(body))), "u1")
	rec := httptest.NewRecorder()

	h.Push(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200", rec.Code)
	}
	if len(store.applied) != 1 {
		t.Fatalf("expected 1 applied change, got %d", len(store.applied))
	}
	// Regression: the delete must reach the store (previously DeletedAt was dropped).
	if store.applied[0].DeletedAt == nil {
		t.Fatal("DeletedAt was not propagated to the store")
	}
}

func TestPushRejectsUnauthenticated(t *testing.T) {
	h := NewHandler(&fakeStore{})
	req := httptest.NewRequest(http.MethodPost, "/sync/push", strings.NewReader(`{"changes":[]}`))
	rec := httptest.NewRecorder()
	h.Push(rec, req) // no user in context
	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want 401", rec.Code)
	}
}

func TestPushRejectsBadJSON(t *testing.T) {
	h := NewHandler(&fakeStore{})
	req := withUser(httptest.NewRequest(http.MethodPost, "/sync/push", strings.NewReader(`{not json`)), "u1")
	rec := httptest.NewRecorder()
	h.Push(rec, req)
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want 400", rec.Code)
	}
}

func TestPushRejectsOversizedBatch(t *testing.T) {
	h := NewHandler(&fakeStore{})
	changes := make([]Change, maxChangesPerPush+1)
	body, _ := json.Marshal(PushRequest{Changes: changes})
	req := withUser(httptest.NewRequest(http.MethodPost, "/sync/push", strings.NewReader(string(body))), "u1")
	rec := httptest.NewRecorder()
	h.Push(rec, req)
	if rec.Code != http.StatusRequestEntityTooLarge {
		t.Fatalf("status = %d, want 413", rec.Code)
	}
}

func TestPushStoreErrorReturns500(t *testing.T) {
	h := NewHandler(&fakeStore{applyErr: context.DeadlineExceeded})
	body, _ := json.Marshal(PushRequest{Changes: []Change{{Table: "t", ID: "1"}}})
	req := withUser(httptest.NewRequest(http.MethodPost, "/sync/push", strings.NewReader(string(body))), "u1")
	rec := httptest.NewRecorder()
	h.Push(rec, req)
	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("status = %d, want 500", rec.Code)
	}
}

func TestPullClampsLimit(t *testing.T) {
	tests := []struct {
		query string
		want  int
	}{
		{"", defaultPullLimit},
		{"?limit=abc", defaultPullLimit},
		{"?limit=0", defaultPullLimit},
		{"?limit=-5", defaultPullLimit},
		{"?limit=50", 50},
		{"?limit=99999", maxPullLimit},
	}
	for _, tt := range tests {
		store := &fakeStore{}
		h := NewHandler(store)
		req := withUser(httptest.NewRequest(http.MethodGet, "/sync/pull"+tt.query, nil), "u1")
		h.Pull(httptest.NewRecorder(), req)
		if store.lastLimit != tt.want {
			t.Errorf("query %q: limit = %d, want %d", tt.query, store.lastLimit, tt.want)
		}
	}
}

func TestPullParsesSince(t *testing.T) {
	store := &fakeStore{}
	h := NewHandler(store)
	ts := "2026-01-02T15:04:05Z"
	req := withUser(httptest.NewRequest(http.MethodGet, "/sync/pull?since="+ts, nil), "u1")
	h.Pull(httptest.NewRecorder(), req)
	want, _ := time.Parse(time.RFC3339Nano, ts)
	if !store.lastSince.Equal(want) {
		t.Fatalf("since = %v, want %v", store.lastSince, want)
	}
}

func TestPullReportsHasMoreAndCursor(t *testing.T) {
	newer := time.Now().UTC()
	older := newer.Add(-time.Hour)
	// Return exactly `limit` rows to signal more pages remain.
	result := make([]Change, defaultPullLimit)
	for i := range result {
		result[i] = Change{Table: "cycles", ID: "x", ServerUpdatedAt: older}
	}
	result[len(result)-1].ServerUpdatedAt = newer // newest cursor
	store := &fakeStore{pullResult: result}
	h := NewHandler(store)

	req := withUser(httptest.NewRequest(http.MethodGet, "/sync/pull", nil), "u1")
	rec := httptest.NewRecorder()
	h.Pull(rec, req)

	var resp PullResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if !resp.HasMore {
		t.Error("expected HasMore=true when result is limit-sized")
	}
	if !resp.Cursor.Equal(newer) {
		t.Errorf("cursor = %v, want newest %v", resp.Cursor, newer)
	}
}
