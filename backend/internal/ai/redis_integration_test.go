package ai

// Real-Redis integration tests for the rate limiter and summary cache. Skipped
// unless RHYTHM_TEST_REDIS_URL points at a throwaway Redis, so `go test ./...`
// stays hermetic. `make itest` boots an ephemeral Redis and sets the env var.
//
// These exercise the actual go-redis INCR/EXPIRE/TTL/GET/SET behavior that the
// unit-test fakes cannot.

import (
	"context"
	"errors"
	"os"
	"testing"
	"time"

	"github.com/redis/go-redis/v9"
)

func testRedis(t *testing.T) *redis.Client {
	t.Helper()
	url := os.Getenv("RHYTHM_TEST_REDIS_URL")
	if url == "" {
		t.Skip("RHYTHM_TEST_REDIS_URL not set; skipping Redis integration test")
	}
	opts, err := redis.ParseURL(url)
	if err != nil {
		t.Fatalf("parse redis url: %v", err)
	}
	rdb := redis.NewClient(opts)
	ctx := context.Background()
	if err := rdb.Ping(ctx).Err(); err != nil {
		t.Fatalf("redis ping: %v", err)
	}
	if err := rdb.FlushDB(ctx).Err(); err != nil { // clean slate per test
		t.Fatalf("flushdb: %v", err)
	}
	t.Cleanup(func() { _ = rdb.Close() })
	return rdb
}

func TestRedisCacheMissSetHit(t *testing.T) {
	rdb := testRedis(t)
	c := NewRedisCache(rdb)
	ctx := context.Background()

	if _, ok, err := c.Get(ctx, "k"); err != nil || ok {
		t.Fatalf("expected miss, got ok=%v err=%v", ok, err)
	}
	if err := c.Set(ctx, "k", "hello", time.Minute); err != nil {
		t.Fatalf("set: %v", err)
	}
	v, ok, err := c.Get(ctx, "k")
	if err != nil || !ok || v != "hello" {
		t.Fatalf("hit failed: v=%q ok=%v err=%v", v, ok, err)
	}
}

func TestRedisCacheTTLExpires(t *testing.T) {
	rdb := testRedis(t)
	c := NewRedisCache(rdb)
	ctx := context.Background()

	if err := c.Set(ctx, "k", "v", 60*time.Millisecond); err != nil {
		t.Fatalf("set: %v", err)
	}
	time.Sleep(150 * time.Millisecond)
	if _, ok, _ := c.Get(ctx, "k"); ok {
		t.Error("value should have expired")
	}
}

func TestRedisRateLimiterAllowsUpToLimitThenDenies(t *testing.T) {
	rdb := testRedis(t)
	rl := NewRedisRateLimiter(rdb, 3, time.Minute)
	ctx := context.Background()

	for i := 1; i <= 3; i++ {
		ok, err := rl.Allow(ctx, "user")
		if err != nil {
			t.Fatalf("allow %d: %v", i, err)
		}
		if !ok {
			t.Fatalf("call %d should be allowed (limit 3)", i)
		}
	}
	ok, err := rl.Allow(ctx, "user")
	if err != nil {
		t.Fatalf("allow 4: %v", err)
	}
	if ok {
		t.Error("4th call should be denied (over limit)")
	}
}

func TestRedisRateLimiterSetsExpiry(t *testing.T) {
	rdb := testRedis(t)
	rl := NewRedisRateLimiter(rdb, 5, time.Minute)
	ctx := context.Background()

	if _, err := rl.Allow(ctx, "user"); err != nil { // n==1 sets expiry
		t.Fatalf("allow: %v", err)
	}
	// The limiter keys by exactly the string passed to Allow.
	ttl, err := rdb.TTL(ctx, "user").Result()
	if err != nil {
		t.Fatalf("ttl: %v", err)
	}
	if ttl <= 0 || ttl > time.Minute {
		t.Errorf("ttl = %v, want (0, 1m]", ttl)
	}
}

func TestRedisRateLimiterWindowResets(t *testing.T) {
	rdb := testRedis(t)
	// Redis EXPIRE is second-granular, so use a realistic (>= 1s) window.
	rl := NewRedisRateLimiter(rdb, 1, 1*time.Second)
	ctx := context.Background()

	ok, _ := rl.Allow(ctx, "user")
	if !ok {
		t.Fatal("first call should be allowed")
	}
	ok, _ = rl.Allow(ctx, "user")
	if ok {
		t.Fatal("second call within window should be denied")
	}
	time.Sleep(1300 * time.Millisecond) // window elapses, counter key expires
	ok, _ = rl.Allow(ctx, "user")
	if !ok {
		t.Error("after the window resets, the call should be allowed again")
	}
}

// Service-level: real Redis cache + limiter, fakes for store + summarizer.
func TestSummaryServiceCacheHitWithRealRedis(t *testing.T) {
	rdb := testRedis(t)
	sum := &fakeSummarizer{out: "generated"}
	svc := NewSummaryService(
		&fakeJournalStore{entries: entries()},
		sum,
		NewRedisRateLimiter(rdb, 5, time.Minute),
		NewRedisCache(rdb),
	)
	ctx := context.Background()

	got, err := svc.GenerateWeeklySummary(ctx, "u1")
	if err != nil || got != "generated" {
		t.Fatalf("first call: got %q err %v", got, err)
	}
	if sum.calls != 1 {
		t.Fatalf("summarizer calls = %d, want 1", sum.calls)
	}

	// Second call must be served from the real Redis cache.
	got2, err := svc.GenerateWeeklySummary(ctx, "u1")
	if err != nil || got2 != "generated" {
		t.Fatalf("second call: got %q err %v", got2, err)
	}
	if sum.calls != 1 {
		t.Errorf("summarizer called again (calls=%d) — Redis cache miss", sum.calls)
	}
}

func TestSummaryServiceRateLimitedWithRealRedis(t *testing.T) {
	rdb := testRedis(t)
	sum := &fakeSummarizer{out: "x"}
	svc := NewSummaryService(
		&fakeJournalStore{entries: entries()},
		sum,
		NewRedisRateLimiter(rdb, 1, time.Minute), // 1 generation/user/window
		NewRedisCache(rdb),
	)
	ctx := context.Background()

	// First (uncached) call consumes the single allowance and caches the result.
	if _, err := svc.GenerateWeeklySummary(ctx, "B"); err != nil {
		t.Fatalf("first: %v", err)
	}
	// Drop the cached summary so the next call must pass through the limiter.
	rdb.Del(ctx, "ai:summary:B")

	_, err := svc.GenerateWeeklySummary(ctx, "B")
	if !errors.Is(err, ErrRateLimited) {
		t.Fatalf("expected ErrRateLimited on the 2nd uncached call, got %v", err)
	}
}
