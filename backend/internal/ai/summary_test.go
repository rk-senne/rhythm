package ai

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/rhythm-app/rhythm-api/internal/auth"
)

type fakeJournalStore struct {
	entries []JournalEntry
	err     error
}

func (f *fakeJournalStore) WeeklyEntries(context.Context, string) ([]JournalEntry, error) {
	return f.entries, f.err
}

type fakeSummarizer struct {
	calls int
	out   string
	err   error
}

func (f *fakeSummarizer) Summarize(context.Context, []JournalEntry) (string, error) {
	f.calls++
	return f.out, f.err
}

type fakeLimiter struct {
	allow bool
	err   error
}

func (f *fakeLimiter) Allow(context.Context, string) (bool, error) { return f.allow, f.err }

type fakeCache struct {
	data     map[string]string
	setCalls int
}

func newFakeCache() *fakeCache { return &fakeCache{data: map[string]string{}} }

func (f *fakeCache) Get(_ context.Context, key string) (string, bool, error) {
	v, ok := f.data[key]
	return v, ok, nil
}

func (f *fakeCache) Set(_ context.Context, key, value string, _ time.Duration) error {
	f.data[key] = value
	f.setCalls++
	return nil
}

func entries() []JournalEntry {
	return []JournalEntry{{Text: "Deep work felt good", CreatedAt: time.Now()}}
}

func TestCacheHitAvoidsOpenAICost(t *testing.T) {
	cache := newFakeCache()
	cache.data["ai:summary:u1"] = "cached summary"
	sum := &fakeSummarizer{out: "fresh"}
	svc := NewSummaryService(&fakeJournalStore{entries: entries()}, sum, &fakeLimiter{allow: true}, cache)

	got, err := svc.GenerateWeeklySummary(context.Background(), "u1")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if got != "cached summary" {
		t.Errorf("got %q, want cached summary", got)
	}
	if sum.calls != 0 {
		t.Errorf("summarizer should not be called on cache hit, calls=%d", sum.calls)
	}
}

func TestRateLimitedReturnsSentinel(t *testing.T) {
	sum := &fakeSummarizer{out: "fresh"}
	svc := NewSummaryService(&fakeJournalStore{entries: entries()}, sum, &fakeLimiter{allow: false}, newFakeCache())

	_, err := svc.GenerateWeeklySummary(context.Background(), "u1")
	if !errors.Is(err, ErrRateLimited) {
		t.Fatalf("err = %v, want ErrRateLimited", err)
	}
	if sum.calls != 0 {
		t.Errorf("summarizer must not run when rate limited, calls=%d", sum.calls)
	}
}

func TestGeneratesAndCaches(t *testing.T) {
	cache := newFakeCache()
	sum := &fakeSummarizer{out: "generated summary"}
	svc := NewSummaryService(&fakeJournalStore{entries: entries()}, sum, &fakeLimiter{allow: true}, cache)

	got, err := svc.GenerateWeeklySummary(context.Background(), "u1")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if got != "generated summary" {
		t.Errorf("got %q", got)
	}
	if sum.calls != 1 {
		t.Errorf("summarizer calls = %d, want 1", sum.calls)
	}
	if cache.setCalls != 1 {
		t.Errorf("cache set calls = %d, want 1", cache.setCalls)
	}
}

func TestEmptyWeekSkipsSummarizer(t *testing.T) {
	sum := &fakeSummarizer{out: "should not run"}
	svc := NewSummaryService(&fakeJournalStore{entries: nil}, sum, &fakeLimiter{allow: true}, newFakeCache())

	got, err := svc.GenerateWeeklySummary(context.Background(), "u1")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if got != emptyWeekMessage {
		t.Errorf("got %q, want empty-week message", got)
	}
	if sum.calls != 0 {
		t.Errorf("summarizer should not run with no entries, calls=%d", sum.calls)
	}
}

func TestSummarizerErrorPropagates(t *testing.T) {
	svc := NewSummaryService(&fakeJournalStore{entries: entries()}, &fakeSummarizer{err: errors.New("openai down")}, &fakeLimiter{allow: true}, newFakeCache())
	if _, err := svc.GenerateWeeklySummary(context.Background(), "u1"); err == nil {
		t.Fatal("expected summarizer error to propagate")
	}
}

func TestHandlerStatusMapping(t *testing.T) {
	tests := []struct {
		name    string
		limiter RateLimiter
		sum     Summarizer
		want    int
	}{
		{"success", &fakeLimiter{allow: true}, &fakeSummarizer{out: "ok"}, http.StatusOK},
		{"rate limited", &fakeLimiter{allow: false}, &fakeSummarizer{out: "ok"}, http.StatusTooManyRequests},
		{"internal error", &fakeLimiter{allow: true}, &fakeSummarizer{err: errors.New("boom")}, http.StatusInternalServerError},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			svc := NewSummaryService(&fakeJournalStore{entries: entries()}, tt.sum, tt.limiter, newFakeCache())
			h := NewHandler(svc)
			req := httptest.NewRequest(http.MethodGet, "/ai/weekly-summary", nil)
			req = req.WithContext(context.WithValue(req.Context(), auth.UserIDKey, "u1"))
			rec := httptest.NewRecorder()
			h.GetWeeklySummary(rec, req)
			if rec.Code != tt.want {
				t.Errorf("status = %d, want %d", rec.Code, tt.want)
			}
		})
	}
}

func TestHandlerRejectsUnauthenticated(t *testing.T) {
	svc := NewSummaryService(&fakeJournalStore{}, &fakeSummarizer{}, &fakeLimiter{allow: true}, newFakeCache())
	h := NewHandler(svc)
	req := httptest.NewRequest(http.MethodGet, "/ai/weekly-summary", nil)
	rec := httptest.NewRecorder()
	h.GetWeeklySummary(rec, req)
	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want 401", rec.Code)
	}
}
