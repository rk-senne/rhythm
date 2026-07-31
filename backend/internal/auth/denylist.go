package auth

import (
	"context"
	"time"

	"github.com/redis/go-redis/v9"
)

// Denylist tracks revoked token IDs (jti). It backs refresh-token rotation with
// reuse detection: when a refresh token is exchanged, its jti is denied for its
// remaining lifetime, so a replayed/stolen copy is rejected.
//
// The interface lives with its consumer (auth); the Redis implementation is a
// plugin — mirroring the ai.RateLimiter / ai.RedisRateLimiter pairing.
type Denylist interface {
	IsDenied(ctx context.Context, jti string) (bool, error)
	Deny(ctx context.Context, jti string, ttl time.Duration) error
}

// NoopDenylist disables revocation. It is the default so the service runs
// without Redis wired (e.g. in tests); refresh tokens still rotate, they just
// aren't tracked for reuse.
type NoopDenylist struct{}

func (NoopDenylist) IsDenied(context.Context, string) (bool, error)    { return false, nil }
func (NoopDenylist) Deny(context.Context, string, time.Duration) error { return nil }

// RedisDenylist stores denied jtis with a TTL equal to the token's remaining
// lifetime, so entries self-expire and the set never grows unbounded.
type RedisDenylist struct {
	rdb *redis.Client
}

func NewRedisDenylist(rdb *redis.Client) *RedisDenylist {
	return &RedisDenylist{rdb: rdb}
}

func (d *RedisDenylist) key(jti string) string { return "auth:denylist:" + jti }

func (d *RedisDenylist) IsDenied(ctx context.Context, jti string) (bool, error) {
	n, err := d.rdb.Exists(ctx, d.key(jti)).Result()
	if err != nil {
		return false, err
	}
	return n > 0, nil
}

func (d *RedisDenylist) Deny(ctx context.Context, jti string, ttl time.Duration) error {
	if ttl <= 0 {
		ttl = time.Minute // guard against non-positive TTLs (would persist forever)
	}
	return d.rdb.Set(ctx, d.key(jti), "1", ttl).Err()
}
