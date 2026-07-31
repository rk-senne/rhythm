package auth

import (
	"context"
	"os"
	"testing"
	"time"

	"github.com/redis/go-redis/v9"
)

// Real-Redis test for RedisDenylist. Skipped unless RHYTHM_TEST_REDIS_URL is
// set (run via `make itest`).
func TestRedisDenylistIntegration(t *testing.T) {
	url := os.Getenv("RHYTHM_TEST_REDIS_URL")
	if url == "" {
		t.Skip("RHYTHM_TEST_REDIS_URL not set; skipping Redis denylist integration test")
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
	_ = rdb.FlushDB(ctx).Err()
	t.Cleanup(func() { _ = rdb.Close() })

	d := NewRedisDenylist(rdb)

	if denied, err := d.IsDenied(ctx, "jti-unknown"); err != nil || denied {
		t.Fatalf("unknown jti should not be denied (denied=%v err=%v)", denied, err)
	}
	if err := d.Deny(ctx, "jti-x", time.Minute); err != nil {
		t.Fatalf("deny: %v", err)
	}
	if denied, _ := d.IsDenied(ctx, "jti-x"); !denied {
		t.Fatal("jti-x should be denied after Deny")
	}
	ttl, err := rdb.TTL(ctx, "auth:denylist:jti-x").Result()
	if err != nil {
		t.Fatalf("ttl: %v", err)
	}
	if ttl <= 0 || ttl > time.Minute {
		t.Errorf("ttl = %v, want (0, 1m]", ttl)
	}
}
