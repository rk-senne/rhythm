package push

import (
	"bytes"
	"context"
	"crypto/ecdsa"
	"crypto/x509"
	"encoding/json"
	"encoding/pem"
	"errors"
	"fmt"
	"io"
	"net/http"
	"sync"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// ErrPermanent marks a delivery failure that must NOT be retried — e.g. an
// unregistered device token (HTTP 410) or a malformed request. The worker drops
// these; transient failures (network, 5xx, 429) return a plain error and are
// retried. (Retrying a dead token forever wastes work and hammers APNs.)
var ErrPermanent = errors.New("permanent delivery failure")

// APNs provider API hosts.
const (
	apnsProdHost    = "https://api.push.apple.com"
	apnsSandboxHost = "https://api.sandbox.push.apple.com"
)

// APNsBaseURL returns the APNs host for the given environment.
func APNsBaseURL(production bool) string {
	if production {
		return apnsProdHost
	}
	return apnsSandboxHost
}

// TokenProvider yields a (cached) APNs provider authentication token.
type TokenProvider interface {
	Token() (string, error)
}

// APNsSender delivers notifications to Apple Push Notification service over
// HTTP/2 with provider-token (JWT) authentication. It implements Sender.
//
// Real APNs requires HTTP/2; Go's default client negotiates h2 over TLS via
// ALPN automatically, so no explicit transport wiring is needed here (a tuned
// http2.Transport can be added later for connection reuse).
type APNsSender struct {
	client   *http.Client
	baseURL  string
	topic    string // the app's bundle id (apns-topic header)
	provider TokenProvider
}

func NewAPNsSender(baseURL, topic string, provider TokenProvider) *APNsSender {
	return &APNsSender{
		client:   &http.Client{Timeout: 10 * time.Second},
		baseURL:  baseURL,
		topic:    topic,
		provider: provider,
	}
}

type apnsPayload struct {
	Aps apsBody `json:"aps"`
}

type apsBody struct {
	Alert apsAlert `json:"alert"`
	Sound string   `json:"sound,omitempty"`
}

type apsAlert struct {
	Title string `json:"title"`
	Body  string `json:"body"`
}

func (s *APNsSender) Send(ctx context.Context, n Notification) error {
	if n.Token == "" {
		return fmt.Errorf("%w: empty device token", ErrPermanent)
	}

	body, err := json.Marshal(apnsPayload{Aps: apsBody{
		Alert: apsAlert{Title: n.Title, Body: n.Body},
		Sound: "default",
	}})
	if err != nil {
		return err
	}

	token, err := s.provider.Token()
	if err != nil {
		return fmt.Errorf("apns: provider token: %w", err) // transient: token minting failed
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, s.baseURL+"/3/device/"+n.Token, bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("authorization", "bearer "+token)
	req.Header.Set("apns-topic", s.topic)
	req.Header.Set("apns-push-type", "alert")
	req.Header.Set("content-type", "application/json")

	resp, err := s.client.Do(req)
	if err != nil {
		return err // network error -> transient, retry
	}
	defer resp.Body.Close()
	_, _ = io.Copy(io.Discard, resp.Body) // drain for connection reuse

	switch {
	case resp.StatusCode == http.StatusOK:
		return nil
	case resp.StatusCode == http.StatusGone, // 410: device token no longer valid
		resp.StatusCode == http.StatusBadRequest, // 400: bad request/topic/token
		resp.StatusCode == http.StatusForbidden:  // 403: auth problem
		return fmt.Errorf("%w: apns status %d", ErrPermanent, resp.StatusCode)
	default:
		// 429 Too Many Requests, 5xx, etc. -> transient, retry.
		return fmt.Errorf("apns status %d", resp.StatusCode)
	}
}

// ES256TokenProvider mints and caches APNs provider JWTs signed with an EC P-256
// key (the .p8 downloaded from the Apple Developer portal). Tokens are reused for
// up to ttl (Apple accepts a provider token for up to 1 hour).
type ES256TokenProvider struct {
	teamID string
	keyID  string
	key    *ecdsa.PrivateKey
	ttl    time.Duration
	now    func() time.Time

	mu       sync.Mutex
	cached   string
	issuedAt time.Time
}

func NewES256TokenProvider(teamID, keyID string, p8PEM []byte) (*ES256TokenProvider, error) {
	key, err := parseP8ECKey(p8PEM)
	if err != nil {
		return nil, err
	}
	return &ES256TokenProvider{
		teamID: teamID,
		keyID:  keyID,
		key:    key,
		ttl:    50 * time.Minute,
		now:    time.Now,
	}, nil
}

func (p *ES256TokenProvider) Token() (string, error) {
	p.mu.Lock()
	defer p.mu.Unlock()

	if p.cached != "" && p.now().Sub(p.issuedAt) < p.ttl {
		return p.cached, nil
	}

	issued := p.now()
	tok := jwt.NewWithClaims(jwt.SigningMethodES256, jwt.MapClaims{
		"iss": p.teamID,
		"iat": issued.Unix(),
	})
	tok.Header["kid"] = p.keyID

	signed, err := tok.SignedString(p.key)
	if err != nil {
		return "", err
	}
	p.cached = signed
	p.issuedAt = issued
	return signed, nil
}

func parseP8ECKey(pemBytes []byte) (*ecdsa.PrivateKey, error) {
	block, _ := pem.Decode(pemBytes)
	if block == nil {
		return nil, errors.New("apns: invalid PEM for provider key")
	}
	parsed, err := x509.ParsePKCS8PrivateKey(block.Bytes)
	if err != nil {
		return nil, fmt.Errorf("apns: parse PKCS8 key: %w", err)
	}
	key, ok := parsed.(*ecdsa.PrivateKey)
	if !ok {
		return nil, errors.New("apns: provider key is not an EC private key")
	}
	return key, nil
}
