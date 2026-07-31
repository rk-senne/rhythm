package sync

import (
	"encoding/json"
	"net/http"
	"strconv"
	"time"

	"github.com/rhythm-app/rhythm-api/internal/auth"
	"github.com/rhythm-app/rhythm-api/internal/web"
)

const (
	defaultPullLimit  = 500
	maxPullLimit      = 1000
	maxChangesPerPush = 1000
	// maxClockSkew bounds how far in the future a client-supplied updated_at may
	// be trusted. Last-write-wins is resolved by the client's clock, so a device
	// with a fast/wrong clock could otherwise stamp a far-future time and win
	// every future conflict permanently. (Kleppmann, DDIA Ch.5: wall-clock LWW
	// is unsafe under clock skew.) Such timestamps are clamped to server time.
	maxClockSkew = 24 * time.Hour
)

type Handler struct {
	store Store
}

func NewHandler(store Store) *Handler {
	return &Handler{store: store}
}

// Change is a single record mutation synced between a device and the server.
type Change struct {
	Table string          `json:"table"`
	ID    string          `json:"id"`
	Data  json.RawMessage `json:"data"`
	// DeletedAt, when set, marks the record as a tombstone. This is now
	// persisted and returned on pull, so deletes propagate across devices.
	DeletedAt *time.Time `json:"deleted_at,omitempty"`
	// UpdatedAt is the client's mutation time, used for last-write-wins.
	UpdatedAt time.Time `json:"updated_at"`
	// ServerUpdatedAt is assigned by the server and used as the pull cursor.
	ServerUpdatedAt time.Time `json:"server_updated_at,omitempty"`
}

type PushRequest struct {
	Changes  []Change `json:"changes"`
	DeviceID string   `json:"device_id"`
}

type PushResponse struct {
	ServerTime time.Time `json:"server_time"`
}

type PullResponse struct {
	Changes []Change `json:"changes"`
	// Cursor is the value the client should pass as ?since on the next pull.
	Cursor time.Time `json:"cursor"`
	// HasMore indicates the result was capped by the limit; pull again.
	HasMore    bool      `json:"has_more"`
	ServerTime time.Time `json:"server_time"`
}

func (h *Handler) Push(w http.ResponseWriter, r *http.Request) {
	userID, ok := r.Context().Value(auth.UserIDKey).(string)
	if !ok || userID == "" {
		web.Error(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	var req PushRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		web.Error(w, http.StatusBadRequest, "invalid request")
		return
	}
	if len(req.Changes) > maxChangesPerPush {
		web.Error(w, http.StatusRequestEntityTooLarge, "too many changes in one push")
		return
	}

	if len(req.Changes) > 0 {
		clampFutureTimestamps(req.Changes, time.Now().UTC(), maxClockSkew)
		if err := h.store.ApplyChanges(r.Context(), userID, req.Changes); err != nil {
			web.Error(w, http.StatusInternalServerError, "sync failed")
			return
		}
	}

	web.JSON(w, http.StatusOK, PushResponse{ServerTime: time.Now().UTC()})
}

// clampFutureTimestamps caps client-supplied timestamps that are implausibly far
// in the future (beyond now+maxSkew) to the server's current time. This bounds
// the damage a client with a bad clock can do to last-write-wins conflict
// resolution without discarding the write itself.
func clampFutureTimestamps(changes []Change, now time.Time, maxSkew time.Duration) {
	limit := now.Add(maxSkew)
	for i := range changes {
		if changes[i].UpdatedAt.After(limit) {
			changes[i].UpdatedAt = now
		}
		if changes[i].DeletedAt != nil && changes[i].DeletedAt.After(limit) {
			clamped := now
			changes[i].DeletedAt = &clamped
		}
	}
}

func (h *Handler) Pull(w http.ResponseWriter, r *http.Request) {
	userID, ok := r.Context().Value(auth.UserIDKey).(string)
	if !ok || userID == "" {
		web.Error(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	since := parseSince(r.URL.Query().Get("since"))
	limit := parseLimit(r.URL.Query().Get("limit"))

	changes, err := h.store.ChangesSince(r.Context(), userID, since, limit)
	if err != nil {
		web.Error(w, http.StatusInternalServerError, "query failed")
		return
	}

	// The cursor is the newest server timestamp we returned, so the next pull
	// resumes exactly where this one stopped regardless of client clock.
	cursor := since
	for _, c := range changes {
		if c.ServerUpdatedAt.After(cursor) {
			cursor = c.ServerUpdatedAt
		}
	}
	if cursor.IsZero() {
		cursor = time.Now().UTC()
	}

	web.JSON(w, http.StatusOK, PullResponse{
		Changes:    changes,
		Cursor:     cursor,
		HasMore:    len(changes) == limit,
		ServerTime: time.Now().UTC(),
	})
}

func parseSince(s string) time.Time {
	if s == "" {
		return time.Time{}
	}
	t, err := time.Parse(time.RFC3339Nano, s)
	if err != nil {
		return time.Time{}
	}
	return t
}

func parseLimit(s string) int {
	if s == "" {
		return defaultPullLimit
	}
	n, err := strconv.Atoi(s)
	if err != nil || n <= 0 {
		return defaultPullLimit
	}
	if n > maxPullLimit {
		return maxPullLimit
	}
	return n
}
