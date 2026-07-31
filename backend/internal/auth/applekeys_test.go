package auth

import (
	"context"
	"crypto/rsa"
	"errors"
	"testing"
	"time"
)

// newTestCache builds a cache with an injected fetch and clock (no network).
func newTestCache(fetch func(ctx context.Context) (map[string]*rsa.PublicKey, error), now func() time.Time, ttl time.Duration) *appleKeyCache {
	return &appleKeyCache{ttl: ttl, now: now, fetch: fetch}
}

func TestAppleKeyCacheServesFromCacheWithinTTL(t *testing.T) {
	calls := 0
	key := &rsa.PublicKey{}
	fetch := func(ctx context.Context) (map[string]*rsa.PublicKey, error) {
		calls++
		return map[string]*rsa.PublicKey{"kid1": key}, nil
	}
	c := newTestCache(fetch, fixedClock(time.Unix(1000, 0)), time.Hour)

	for i := 0; i < 5; i++ {
		got, err := c.get(context.Background(), "kid1")
		if err != nil {
			t.Fatalf("get: %v", err)
		}
		if got != key {
			t.Fatal("returned wrong key")
		}
	}
	if calls != 1 {
		t.Fatalf("expected 1 fetch within TTL, got %d", calls)
	}
}

func TestAppleKeyCacheRefetchesAfterTTL(t *testing.T) {
	calls := 0
	now := time.Unix(1000, 0)
	fetch := func(ctx context.Context) (map[string]*rsa.PublicKey, error) {
		calls++
		return map[string]*rsa.PublicKey{"kid1": {}}, nil
	}
	c := newTestCache(fetch, func() time.Time { return now }, time.Hour)

	if _, err := c.get(context.Background(), "kid1"); err != nil {
		t.Fatalf("get 1: %v", err)
	}
	now = now.Add(2 * time.Hour) // advance past TTL
	if _, err := c.get(context.Background(), "kid1"); err != nil {
		t.Fatalf("get 2: %v", err)
	}
	if calls != 2 {
		t.Fatalf("expected refetch after TTL, got %d fetches", calls)
	}
}

func TestAppleKeyCacheRefetchesOnUnknownKid(t *testing.T) {
	calls := 0
	fetch := func(ctx context.Context) (map[string]*rsa.PublicKey, error) {
		calls++
		if calls == 1 {
			return map[string]*rsa.PublicKey{"old-kid": {}}, nil
		}
		return map[string]*rsa.PublicKey{"old-kid": {}, "new-kid": {}}, nil
	}
	c := newTestCache(fetch, fixedClock(time.Unix(1000, 0)), time.Hour)

	if _, err := c.get(context.Background(), "new-kid"); err != nil {
		t.Fatalf("expected refetch to discover new-kid: %v", err)
	}
	if calls != 2 {
		t.Fatalf("expected 2 fetches (rotation refetch), got %d", calls)
	}
}

func TestAppleKeyCacheUsesStaleKeyWhenRefreshFails(t *testing.T) {
	calls := 0
	now := time.Unix(1000, 0)
	fetch := func(ctx context.Context) (map[string]*rsa.PublicKey, error) {
		calls++
		if calls == 1 {
			return map[string]*rsa.PublicKey{"kid1": {}}, nil
		}
		return nil, errors.New("apple unreachable")
	}
	c := newTestCache(fetch, func() time.Time { return now }, time.Hour)

	if _, err := c.get(context.Background(), "kid1"); err != nil {
		t.Fatalf("get 1: %v", err)
	}
	now = now.Add(2 * time.Hour) // force refresh, which will fail
	got, err := c.get(context.Background(), "kid1")
	if err != nil {
		t.Fatalf("expected stale fallback, got error: %v", err)
	}
	if got == nil {
		t.Fatal("expected a stale key, got nil")
	}
}

func TestAppleKeyCacheReturnsErrorWhenUnknownKidAndRefreshFails(t *testing.T) {
	fetch := func(ctx context.Context) (map[string]*rsa.PublicKey, error) {
		return nil, errors.New("apple unreachable")
	}
	c := newTestCache(fetch, fixedClock(time.Unix(1000, 0)), time.Hour)
	if _, err := c.get(context.Background(), "kid1"); err == nil {
		t.Fatal("expected error when no keys and fetch fails")
	}
}
