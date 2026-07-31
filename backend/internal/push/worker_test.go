package push

import (
	"context"
	"errors"
	"testing"
)

type fakeSender struct {
	sent []Notification
	err  error
}

func (f *fakeSender) Send(_ context.Context, n Notification) error {
	if f.err != nil {
		return f.err
	}
	f.sent = append(f.sent, n)
	return nil
}

func TestDeliverSkipsMalformedAndSendsValid(t *testing.T) {
	sender := &fakeSender{}
	w := NewWorker(nil, sender)

	payloads := []string{
		`{"user_id":"u1","token":"tok1","title":"Focus time","body":"Start a cycle"}`,
		`not-json`,
		`{"user_id":"u2","title":"no token"}`, // missing token -> dropped
		`{"user_id":"u3","token":"tok3","title":"Ritual","body":"Breathe"}`,
	}

	failed := w.deliver(context.Background(), payloads)

	if len(sender.sent) != 2 {
		t.Fatalf("expected 2 valid deliveries, got %d", len(sender.sent))
	}
	if len(failed) != 0 {
		t.Errorf("no sends failed, so nothing should be retried; got %d", len(failed))
	}
	if sender.sent[0].Token != "tok1" || sender.sent[1].Token != "tok3" {
		t.Errorf("unexpected delivered tokens: %+v", sender.sent)
	}
}

func TestDeliverReturnsFailedSendsForRetry(t *testing.T) {
	sender := &fakeSender{err: errors.New("apns down")}
	w := NewWorker(nil, sender)

	failed := w.deliver(context.Background(), []string{
		`{"user_id":"u1","token":"tok1","title":"x"}`, // send fails -> retry
		`{"user_id":"u2","title":"no token"}`,         // malformed -> dropped, not retried
	})

	if len(failed) != 1 {
		t.Fatalf("expected 1 failed send returned for retry, got %d", len(failed))
	}
	if failed[0].UserID != "u1" {
		t.Errorf("wrong notification returned for retry: %+v", failed[0])
	}
}

func TestDeliverDropsPermanentFailures(t *testing.T) {
	// A permanent failure (e.g. an unregistered device token) must NOT be retried.
	sender := &fakeSender{err: ErrPermanent}
	w := NewWorker(nil, sender)

	failed := w.deliver(context.Background(), []string{
		`{"user_id":"u1","token":"dead","title":"x"}`,
	})
	if len(failed) != 0 {
		t.Fatalf("permanent failures must be dropped, not retried; got %d", len(failed))
	}
}

func TestDecodeNotification(t *testing.T) {
	if _, err := decodeNotification(`{"token":"t","title":"x"}`); err != nil {
		t.Errorf("valid payload: unexpected error %v", err)
	}
	if _, err := decodeNotification(`{bad`); err == nil {
		t.Error("expected error for malformed JSON")
	}
	if _, err := decodeNotification(`{"title":"no token"}`); err == nil {
		t.Error("expected error for missing device token")
	}
}

func TestNewWorkerDefaultsSender(t *testing.T) {
	w := NewWorker(nil, nil)
	if w.sender == nil {
		t.Fatal("expected a default sender when nil is passed")
	}
}
