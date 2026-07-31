package ai

import (
	"context"
	"time"

	"github.com/redis/go-redis/v9"
)

// RedisRateLimiter is a fixed-window per-key limiter: at most `limit` calls per
// `window`. Used to cap expensive OpenAI summary generation per user.
type RedisRateLimiter struct {
	rdb    *redis.Client
	limit  int
	window time.Duration
}

func NewRedisRateLimiter(rdb *redis.Client, limit int, window time.Duration) *RedisRateLimiter {
	return &RedisRateLimiter{rdb: rdb, limit: limit, window: window}
}

func (r *RedisRateLimiter) Allow(ctx context.Context, key string) (bool, error) {
	n, err := r.rdb.Incr(ctx, key).Result()
	if err != nil {
		return false, err
	}
	if n == 1 {
		// First hit in this window — set the expiry.
		if err := r.rdb.Expire(ctx, key, r.window).Err(); err != nil {
			return false, err
		}
	}
	return n <= int64(r.limit), nil
}

// RedisCache stores string values with a TTL.
type RedisCache struct {
	rdb *redis.Client
}

func NewRedisCache(rdb *redis.Client) *RedisCache {
	return &RedisCache{rdb: rdb}
}

func (c *RedisCache) Get(ctx context.Context, key string) (string, bool, error) {
	v, err := c.rdb.Get(ctx, key).Result()
	if err == redis.Nil {
		return "", false, nil
	}
	if err != nil {
		return "", false, err
	}
	return v, true, nil
}

func (c *RedisCache) Set(ctx context.Context, key, value string, ttl time.Duration) error {
	return c.rdb.Set(ctx, key, value, ttl).Err()
}
