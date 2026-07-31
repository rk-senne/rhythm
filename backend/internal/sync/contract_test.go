package sync

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

// TestPushDecodesIOSWireFormat feeds the exact JSON the iOS SyncClient emits
// (RFC3339 dates, optional deleted_at tombstone, arbitrary data) and asserts the
// handler decodes every field. This locks the wire contract between the two
// codebases so a field-name or date-format change fails CI.
func TestPushDecodesIOSWireFormat(t *testing.T) {
	store := &fakeStore{}
	h := NewHandler(store)

	body := `{
      "changes": [
        {"table":"cycles","id":"C1","data":{"focus_duration":5400},"updated_at":"2026-07-31T10:00:00Z"},
        {"table":"journal_entries","id":"J1","data":{"text":"hi"},"updated_at":"2026-07-31T10:05:00Z","deleted_at":"2026-07-31T10:06:00Z"}
      ],
      "device_id":"device-abc"
    }`
	req := withUser(httptest.NewRequest(http.MethodPost, "/sync/push", strings.NewReader(body)), "u1")
	rec := httptest.NewRecorder()
	h.Push(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200; body=%s", rec.Code, rec.Body.String())
	}
	if len(store.applied) != 2 {
		t.Fatalf("applied %d changes, want 2", len(store.applied))
	}

	// Change 0: a normal upsert, no tombstone, RFC3339 updated_at parsed.
	if store.applied[0].Table != "cycles" || store.applied[0].ID != "C1" {
		t.Errorf("change 0 = %+v", store.applied[0])
	}
	if store.applied[0].DeletedAt != nil {
		t.Error("change 0 should not be a tombstone")
	}
	wantUpdated, _ := time.Parse(time.RFC3339, "2026-07-31T10:00:00Z")
	if !store.applied[0].UpdatedAt.Equal(wantUpdated) {
		t.Errorf("updated_at = %v, want %v", store.applied[0].UpdatedAt, wantUpdated)
	}

	// Change 1: a delete tombstone parsed from RFC3339.
	if store.applied[1].DeletedAt == nil {
		t.Fatal("change 1 should carry a deleted_at tombstone")
	}
	wantDeleted, _ := time.Parse(time.RFC3339, "2026-07-31T10:06:00Z")
	if !store.applied[1].DeletedAt.Equal(wantDeleted) {
		t.Errorf("deleted_at = %v, want %v", store.applied[1].DeletedAt, wantDeleted)
	}
}

// TestPullResponseHasContractFields asserts the pull response contains exactly
// the fields the iOS client decodes: changes, cursor, has_more, server_time.
func TestPullResponseHasContractFields(t *testing.T) {
	now := time.Now().UTC()
	store := &fakeStore{pullResult: []Change{
		{Table: "cycles", ID: "C1", Data: json.RawMessage(`{"x":1}`), UpdatedAt: now, ServerUpdatedAt: now},
	}}
	h := NewHandler(store)

	req := withUser(httptest.NewRequest(http.MethodGet, "/sync/pull", nil), "u1")
	rec := httptest.NewRecorder()
	h.Pull(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200", rec.Code)
	}
	if ct := rec.Header().Get("Content-Type"); !strings.Contains(ct, "application/json") {
		t.Errorf("Content-Type = %q, want application/json", ct)
	}

	var raw map[string]json.RawMessage
	if err := json.Unmarshal(rec.Body.Bytes(), &raw); err != nil {
		t.Fatalf("decode: %v", err)
	}
	for _, key := range []string{"changes", "cursor", "has_more", "server_time"} {
		if _, ok := raw[key]; !ok {
			t.Errorf("pull response missing %q (iOS SyncClient depends on it)", key)
		}
	}
}
