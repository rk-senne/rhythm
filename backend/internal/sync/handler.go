package sync

import (
	"encoding/json"
	"net/http"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/rhythm-app/rhythm-api/internal/auth"
)

type Handler struct {
	db *pgxpool.Pool
}

func NewHandler(db *pgxpool.Pool) *Handler {
	return &Handler{db: db}
}

type Change struct {
	Table     string          `json:"table"`
	ID        string          `json:"id"`
	Data      json.RawMessage `json:"data"`
	DeletedAt *time.Time      `json:"deleted_at,omitempty"`
	UpdatedAt time.Time       `json:"updated_at"`
}

type PushRequest struct {
	Changes  []Change `json:"changes"`
	DeviceID string   `json:"device_id"`
}

type PushResponse struct {
	ServerTime time.Time `json:"server_time"`
}

type PullResponse struct {
	Changes    []Change  `json:"changes"`
	ServerTime time.Time `json:"server_time"`
}

func (h *Handler) Push(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value(auth.UserIDKey).(string)

	var req PushRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid request", http.StatusBadRequest)
		return
	}

	for _, c := range req.Changes {
		_, err := h.db.Exec(r.Context(),
			`INSERT INTO sync_changes (user_id, table_name, record_id, data, updated_at)
			 VALUES ($1, $2, $3, $4, $5)
			 ON CONFLICT (user_id, table_name, record_id) DO UPDATE SET data = $4, updated_at = $5`,
			userID, c.Table, c.ID, c.Data, c.UpdatedAt,
		)
		if err != nil {
			http.Error(w, "sync failed", http.StatusInternalServerError)
			return
		}
	}

	json.NewEncoder(w).Encode(PushResponse{ServerTime: time.Now().UTC()})
}

func (h *Handler) Pull(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value(auth.UserIDKey).(string)
	since := r.URL.Query().Get("since")

	sinceTime, err := time.Parse(time.RFC3339, since)
	if err != nil {
		sinceTime = time.Time{}
	}

	rows, err := h.db.Query(r.Context(),
		`SELECT table_name, record_id, data, updated_at FROM sync_changes
		 WHERE user_id = $1 AND updated_at > $2 ORDER BY updated_at`,
		userID, sinceTime,
	)
	if err != nil {
		http.Error(w, "query failed", http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	var changes []Change
	for rows.Next() {
		var c Change
		if err := rows.Scan(&c.Table, &c.ID, &c.Data, &c.UpdatedAt); err != nil {
			continue
		}
		changes = append(changes, c)
	}

	json.NewEncoder(w).Encode(PullResponse{Changes: changes, ServerTime: time.Now().UTC()})
}
