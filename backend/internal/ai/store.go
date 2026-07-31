package ai

import (
	"context"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

// PgJournalStore reads journal entries from Postgres.
type PgJournalStore struct {
	db *pgxpool.Pool
}

func NewPgJournalStore(db *pgxpool.Pool) *PgJournalStore {
	return &PgJournalStore{db: db}
}

func (s *PgJournalStore) WeeklyEntries(ctx context.Context, userID string) ([]JournalEntry, error) {
	weekAgo := time.Now().AddDate(0, 0, -7)
	rows, err := s.db.Query(ctx,
		`SELECT text, mood, created_at FROM journal_entries
		 WHERE user_id = $1 AND created_at > $2 ORDER BY created_at`,
		userID, weekAgo,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var entries []JournalEntry
	for rows.Next() {
		var e JournalEntry
		if err := rows.Scan(&e.Text, &e.Mood, &e.CreatedAt); err != nil {
			return nil, err
		}
		entries = append(entries, e)
	}
	return entries, rows.Err()
}
