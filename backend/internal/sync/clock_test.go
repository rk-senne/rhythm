package sync

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func TestClampFutureTimestamps(t *testing.T) {
	now := time.Date(2026, 7, 31, 12, 0, 0, 0, time.UTC)
	farFuture := now.Add(48 * time.Hour)
	past := now.Add(-time.Hour)

	changes := []Change{
		{ID: "future", UpdatedAt: farFuture},
		{ID: "normal", UpdatedAt: past},
		{ID: "future-delete", UpdatedAt: farFuture, DeletedAt: &farFuture},
	}
	clampFutureTimestamps(changes, now, maxClockSkew)

	if !changes[0].UpdatedAt.Equal(now) {
		t.Errorf("far-future updated_at should clamp to now; got %v", changes[0].UpdatedAt)
	}
	if !changes[1].UpdatedAt.Equal(past) {
		t.Errorf("a normal (past) updated_at must be untouched; got %v", changes[1].UpdatedAt)
	}
	if changes[2].DeletedAt == nil || !changes[2].DeletedAt.Equal(now) {
		t.Errorf("far-future deleted_at should clamp to now; got %v", changes[2].DeletedAt)
	}
}

func TestPushClampsFutureClientClock(t *testing.T) {
	store := &fakeStore{}
	h := NewHandler(store)

	future := time.Now().UTC().Add(72 * time.Hour)
	body, _ := json.Marshal(PushRequest{Changes: []Change{
		{Table: "cycles", ID: "c1", Data: json.RawMessage(`{}`), UpdatedAt: future},
	}})
	req := withUser(httptest.NewRequest(http.MethodPost, "/sync/push", strings.NewReader(string(body))), "u1")
	h.Push(httptest.NewRecorder(), req)

	if len(store.applied) != 1 {
		t.Fatalf("want 1 applied change, got %d", len(store.applied))
	}
	if store.applied[0].UpdatedAt.After(time.Now().UTC().Add(maxClockSkew + time.Minute)) {
		t.Errorf("Push did not clamp a far-future client clock: %v", store.applied[0].UpdatedAt)
	}
}
