package push

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"time"

	"github.com/redis/go-redis/v9"
)

const queueKey = "push:queue"

// retryDelay is how long a failed delivery waits before it becomes due again.
const retryDelay = 60 * time.Second

// Notification is a scheduled push payload stored in the Redis sorted set,
// scored by its due time (unix seconds).
type Notification struct {
	UserID string `json:"user_id"`
	Token  string `json:"token"` // APNs device token
	Title  string `json:"title"`
	Body   string `json:"body"`
}

// Sender delivers a notification. Abstracting it keeps scheduling logic testable
// and lets the real APNs HTTP/2 transport be swapped in without changes here.
type Sender interface {
	Send(ctx context.Context, n Notification) error
}

// LogSender is the default Sender until the APNs transport is implemented. It
// logs deliveries instead of silently dropping them (the previous behavior).
type LogSender struct{}

func (LogSender) Send(_ context.Context, n Notification) error {
	slog.Info("push delivery (APNs transport pending)", "user_id", n.UserID, "title", n.Title)
	return nil
}

type Worker struct {
	rdb    *redis.Client
	sender Sender
	batch  int
}

func NewWorker(rdb *redis.Client, sender Sender) *Worker {
	if sender == nil {
		sender = LogSender{}
	}
	return &Worker{rdb: rdb, sender: sender, batch: 100}
}

func (w *Worker) Run(ctx context.Context) {
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			if err := w.processDue(ctx, time.Now()); err != nil {
				slog.Error("push: processing due notifications failed", "error", err)
			}
		}
	}
}

// dequeueScript atomically pops due members (score <= now) up to a limit.
// Combining ZRANGEBYSCORE and ZREM in one script removes the race where two
// workers read the same member and double-send.
var dequeueScript = redis.NewScript(`
local due = redis.call('ZRANGEBYSCORE', KEYS[1], '-inf', ARGV[1], 'LIMIT', 0, tonumber(ARGV[2]))
if #due > 0 then
  redis.call('ZREM', KEYS[1], unpack(due))
end
return due
`)

func (w *Worker) processDue(ctx context.Context, now time.Time) error {
	payloads, err := w.dequeueDue(ctx, now)
	if err != nil {
		return err
	}
	// Re-enqueue transient send failures so a delivery is retried rather than
	// silently lost (a completed dequeue would otherwise be at-most-once).
	for _, n := range w.deliver(ctx, payloads) {
		if err := w.enqueue(ctx, n, now.Add(retryDelay)); err != nil {
			slog.Error("push: re-enqueue after failure failed", "user_id", n.UserID, "error", err)
		}
	}
	return nil
}

func (w *Worker) dequeueDue(ctx context.Context, now time.Time) ([]string, error) {
	return dequeueScript.Run(ctx, w.rdb, []string{queueKey},
		fmt.Sprintf("%d", now.Unix()), w.batch).StringSlice()
}

// enqueue (re)schedules a notification to become due at time `at`.
func (w *Worker) enqueue(ctx context.Context, n Notification, at time.Time) error {
	payload, err := json.Marshal(n)
	if err != nil {
		return err
	}
	return w.rdb.ZAdd(ctx, queueKey, redis.Z{
		Score:  float64(at.Unix()),
		Member: string(payload),
	}).Err()
}

// deliver decodes and sends each payload, returning the notifications whose send
// failed (so the caller can retry them). Malformed payloads are dropped — they
// will never succeed — rather than retried forever. It has no Redis dependency,
// so it is unit-tested directly with a fake Sender.
func (w *Worker) deliver(ctx context.Context, payloads []string) []Notification {
	var failed []Notification
	for _, p := range payloads {
		n, err := decodeNotification(p)
		if err != nil {
			slog.Error("push: dropping malformed payload", "error", err)
			continue
		}
		if err := w.sender.Send(ctx, n); err != nil {
			if errors.Is(err, ErrPermanent) {
				slog.Error("push: permanent failure, dropping", "user_id", n.UserID, "error", err)
				continue
			}
			slog.Error("push: send failed, will retry", "user_id", n.UserID, "error", err)
			failed = append(failed, n)
		}
	}
	return failed
}

func decodeNotification(payload string) (Notification, error) {
	var n Notification
	if err := json.Unmarshal([]byte(payload), &n); err != nil {
		return Notification{}, err
	}
	if n.Token == "" {
		return Notification{}, fmt.Errorf("notification missing device token")
	}
	return n, nil
}
