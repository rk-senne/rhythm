package sync

import (
	"context"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

// Store persists and retrieves per-user sync changes. Defining it as an
// interface lets the HTTP handler be unit-tested without a live database.
type Store interface {
	// ApplyChanges upserts a batch of changes atomically. Last-write-wins is
	// resolved by the client's UpdatedAt, but the pull cursor is driven by a
	// server-assigned timestamp so client clock skew cannot cause a device to
	// miss changes.
	ApplyChanges(ctx context.Context, userID string, changes []Change) error
	// ChangesSince returns up to limit changes with server_updated_at strictly
	// greater than since, ordered ascending (oldest first) for stable paging.
	ChangesSince(ctx context.Context, userID string, since time.Time, limit int) ([]Change, error)
}

// PgStore is the Postgres-backed Store.
type PgStore struct {
	db *pgxpool.Pool
}

func NewPgStore(db *pgxpool.Pool) *PgStore {
	return &PgStore{db: db}
}

func (s *PgStore) ApplyChanges(ctx context.Context, userID string, changes []Change) error {
	tx, err := s.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx) //nolint:errcheck // no-op after a successful commit

	const q = `
INSERT INTO sync_changes (user_id, table_name, record_id, data, updated_at, deleted_at, server_updated_at)
VALUES ($1, $2, $3, $4, $5, $6, now())
ON CONFLICT (user_id, table_name, record_id) DO UPDATE
SET data = EXCLUDED.data,
    updated_at = EXCLUDED.updated_at,
    deleted_at = EXCLUDED.deleted_at,
    server_updated_at = now()
WHERE sync_changes.updated_at <= EXCLUDED.updated_at`

	for _, c := range changes {
		if _, err := tx.Exec(ctx, q, userID, c.Table, c.ID, c.Data, c.UpdatedAt, c.DeletedAt); err != nil {
			return err
		}
	}
	return tx.Commit(ctx)
}

func (s *PgStore) ChangesSince(ctx context.Context, userID string, since time.Time, limit int) ([]Change, error) {
	const q = `
SELECT table_name, record_id, data, updated_at, deleted_at, server_updated_at
FROM sync_changes
WHERE user_id = $1 AND server_updated_at > $2
ORDER BY server_updated_at ASC
LIMIT $3`

	rows, err := s.db.Query(ctx, q, userID, since, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var changes []Change
	for rows.Next() {
		var c Change
		if err := rows.Scan(&c.Table, &c.ID, &c.Data, &c.UpdatedAt, &c.DeletedAt, &c.ServerUpdatedAt); err != nil {
			return nil, err
		}
		changes = append(changes, c)
	}
	return changes, rows.Err()
}
