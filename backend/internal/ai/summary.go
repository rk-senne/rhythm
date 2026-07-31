package ai

import (
	"context"
	"errors"
	"time"
)

// ErrRateLimited is returned when a user exceeds their AI summary allowance.
var ErrRateLimited = errors.New("ai summary rate limit exceeded")

const emptyWeekMessage = "No journal entries this week. Start reflecting after your focus sessions!"

// defaultCacheTTL is how long a generated weekly summary is served from cache
// before regeneration (bounds OpenAI spend; a day-stale weekly summary is fine).
const defaultCacheTTL = 24 * time.Hour

// JournalEntry is a single reflection used to build a weekly summary.
type JournalEntry struct {
	Text      string    `json:"text"`
	Mood      *string   `json:"mood"`
	CreatedAt time.Time `json:"created_at"`
}

// JournalStore fetches a user's recent journal entries.
type JournalStore interface {
	WeeklyEntries(ctx context.Context, userID string) ([]JournalEntry, error)
}

// Summarizer turns journal entries into a natural-language summary (e.g. via an
// LLM). Abstracted so the OpenAI call can be faked in tests.
type Summarizer interface {
	Summarize(ctx context.Context, entries []JournalEntry) (string, error)
}

// RateLimiter guards expensive operations on a per-key basis.
type RateLimiter interface {
	Allow(ctx context.Context, key string) (bool, error)
}

// Cache stores generated summaries so we don't pay to regenerate them on every
// request (the previous behavior hit OpenAI on every call).
type Cache interface {
	Get(ctx context.Context, key string) (string, bool, error)
	Set(ctx context.Context, key, value string, ttl time.Duration) error
}

// SummaryService orchestrates cache -> rate limit -> fetch -> summarize.
type SummaryService struct {
	store      JournalStore
	summarizer Summarizer
	limiter    RateLimiter
	cache      Cache
	cacheTTL   time.Duration
}

func NewSummaryService(store JournalStore, summarizer Summarizer, limiter RateLimiter, cache Cache) *SummaryService {
	return &SummaryService{
		store:      store,
		summarizer: summarizer,
		limiter:    limiter,
		cache:      cache,
		cacheTTL:   defaultCacheTTL,
	}
}

// GenerateWeeklySummary returns a cached summary if available; otherwise it
// checks the per-user rate limit, fetches entries, generates a summary, and
// caches it. Cache hits do not consume rate-limit budget.
func (s *SummaryService) GenerateWeeklySummary(ctx context.Context, userID string) (string, error) {
	cacheKey := "ai:summary:" + userID

	if s.cache != nil {
		if v, ok, err := s.cache.Get(ctx, cacheKey); err == nil && ok {
			return v, nil
		}
	}

	if s.limiter != nil {
		allowed, err := s.limiter.Allow(ctx, "ai:rate:"+userID)
		if err != nil {
			return "", err
		}
		if !allowed {
			return "", ErrRateLimited
		}
	}

	entries, err := s.store.WeeklyEntries(ctx, userID)
	if err != nil {
		return "", err
	}
	if len(entries) == 0 {
		return emptyWeekMessage, nil
	}

	summary, err := s.summarizer.Summarize(ctx, entries)
	if err != nil {
		return "", err
	}

	if s.cache != nil {
		// Best-effort cache write; a failure here shouldn't fail the request.
		_ = s.cache.Set(ctx, cacheKey, summary, s.cacheTTL)
	}
	return summary, nil
}
