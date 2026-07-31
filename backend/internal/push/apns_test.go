package push

import (
	"context"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/x509"
	"encoding/json"
	"encoding/pem"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/golang-jwt/jwt/v5"
)

// generateP8 makes an EC P-256 private key in PKCS8 PEM form, like Apple's .p8.
func generateP8(t *testing.T) ([]byte, *ecdsa.PrivateKey) {
	t.Helper()
	key, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatalf("generate key: %v", err)
	}
	der, err := x509.MarshalPKCS8PrivateKey(key)
	if err != nil {
		t.Fatalf("marshal key: %v", err)
	}
	return pem.EncodeToMemory(&pem.Block{Type: "PRIVATE KEY", Bytes: der}), key
}

func TestES256TokenProviderSignsValidJWT(t *testing.T) {
	p8, key := generateP8(t)
	p, err := NewES256TokenProvider("TEAMID1234", "KEYID5678", p8)
	if err != nil {
		t.Fatalf("provider: %v", err)
	}

	tokenStr, err := p.Token()
	if err != nil {
		t.Fatalf("token: %v", err)
	}

	parsed, err := jwt.Parse(tokenStr, func(*jwt.Token) (any, error) {
		return key.Public(), nil
	}, jwt.WithValidMethods([]string{"ES256"}))
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	if kid, _ := parsed.Header["kid"].(string); kid != "KEYID5678" {
		t.Errorf("kid header = %q, want KEYID5678", kid)
	}
	claims, _ := parsed.Claims.(jwt.MapClaims)
	if iss, _ := claims["iss"].(string); iss != "TEAMID1234" {
		t.Errorf("iss claim = %q, want TEAMID1234", iss)
	}
	if _, ok := claims["iat"]; !ok {
		t.Error("missing iat claim")
	}
}

func TestES256TokenProviderCachesWithinTTL(t *testing.T) {
	p8, _ := generateP8(t)
	p, _ := NewES256TokenProvider("T", "K", p8)
	a, _ := p.Token()
	b, _ := p.Token()
	if a != b {
		t.Error("provider token should be cached and reused within its TTL")
	}
}

func TestES256TokenProviderRejectsBadKey(t *testing.T) {
	if _, err := NewES256TokenProvider("T", "K", []byte("not a pem")); err == nil {
		t.Fatal("expected an error for an invalid PEM key")
	}
}

type staticProvider struct{ tok string }

func (s staticProvider) Token() (string, error) { return s.tok, nil }

func TestAPNsSenderSuccessSendsCorrectRequest(t *testing.T) {
	var gotPath, gotAuth, gotTopic, gotPushType string
	var gotBody apnsPayload
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotPath = r.URL.Path
		gotAuth = r.Header.Get("authorization")
		gotTopic = r.Header.Get("apns-topic")
		gotPushType = r.Header.Get("apns-push-type")
		_ = json.NewDecoder(r.Body).Decode(&gotBody)
		w.WriteHeader(http.StatusOK)
	}))
	defer srv.Close()

	s := NewAPNsSender(srv.URL, "com.rhythm.app", staticProvider{tok: "prov-token"})
	err := s.Send(context.Background(), Notification{Token: "dev-token-123", Title: "Focus", Body: "Time to reset"})
	if err != nil {
		t.Fatalf("send: %v", err)
	}

	if gotPath != "/3/device/dev-token-123" {
		t.Errorf("path = %q, want /3/device/dev-token-123", gotPath)
	}
	if gotAuth != "bearer prov-token" {
		t.Errorf("authorization = %q, want 'bearer prov-token'", gotAuth)
	}
	if gotTopic != "com.rhythm.app" {
		t.Errorf("apns-topic = %q", gotTopic)
	}
	if gotPushType != "alert" {
		t.Errorf("apns-push-type = %q, want alert", gotPushType)
	}
	if gotBody.Aps.Alert.Title != "Focus" || gotBody.Aps.Alert.Body != "Time to reset" {
		t.Errorf("payload alert = %+v", gotBody.Aps.Alert)
	}
}

func TestAPNsSenderPermanentOn410(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusGone) // 410: unregistered device token
	}))
	defer srv.Close()
	s := NewAPNsSender(srv.URL, "topic", staticProvider{tok: "t"})
	err := s.Send(context.Background(), Notification{Token: "dead", Title: "x"})
	if !errors.Is(err, ErrPermanent) {
		t.Fatalf("410 should be a permanent failure, got %v", err)
	}
}

func TestAPNsSenderTransientOn500(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
	}))
	defer srv.Close()
	s := NewAPNsSender(srv.URL, "topic", staticProvider{tok: "t"})
	err := s.Send(context.Background(), Notification{Token: "d", Title: "x"})
	if err == nil {
		t.Fatal("500 should return an error")
	}
	if errors.Is(err, ErrPermanent) {
		t.Error("500 should be transient (retryable), not permanent")
	}
}

func TestAPNsSenderEmptyTokenIsPermanent(t *testing.T) {
	s := NewAPNsSender("http://unused.invalid", "topic", staticProvider{tok: "t"})
	err := s.Send(context.Background(), Notification{Token: "", Title: "x"})
	if !errors.Is(err, ErrPermanent) {
		t.Fatalf("empty device token should be permanent, got %v", err)
	}
}
