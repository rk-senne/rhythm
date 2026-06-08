package push

import (
	"context"
	"fmt"
	"log/slog"
	"time"

	"github.com/redis/go-redis/v9"
)

type Worker struct {
	rdb *redis.Client
}

func NewWorker(rdb *redis.Client) *Worker {
	return &Worker{rdb: rdb}
}

func (w *Worker) Run(ctx context.Context) {
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			w.processDue(ctx)
		}
	}
}

func (w *Worker) processDue(ctx context.Context) {
	now := float64(time.Now().Unix())
	results, err := w.rdb.ZRangeByScore(ctx, "push:queue", &redis.ZRangeBy{
		Min: "-inf", Max: fmt.Sprintf("%f", now), Count: 100,
	}).Result()
	if err != nil {
		slog.Error("failed to fetch due notifications", "error", err)
		return
	}

	for _, payload := range results {
		// TODO: decode payload, send via APNs HTTP/2
		slog.Info("sending push notification", "payload", payload)
		w.rdb.ZRem(ctx, "push:queue", payload)
	}
}
