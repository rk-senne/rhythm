package auth

import (
	"context"
	"crypto/rsa"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"math/big"
	"net/http"
	"sync"
	"time"
)

// appleKeysURL is Apple's JWKS endpoint for Sign in with Apple.
const appleKeysURL = "https://appleid.apple.com/auth/keys"

type appleKey struct {
	Kty string `json:"kty"`
	Kid string `json:"kid"`
	Use string `json:"use"`
	Alg string `json:"alg"`
	N   string `json:"n"`
	E   string `json:"e"`
}

type appleKeysResponse struct {
	Keys []appleKey `json:"keys"`
}

// appleKeyCache caches Apple's public signing keys with a TTL. Previously every
// sign-in triggered a network fetch of Apple's JWKS; under load that is slow and
// a dependency/DoS risk. now and fetch are injectable for deterministic tests.
type appleKeyCache struct {
	mu        sync.Mutex
	keys      map[string]*rsa.PublicKey
	fetchedAt time.Time
	ttl       time.Duration
	now       func() time.Time
	fetch     func(ctx context.Context) (map[string]*rsa.PublicKey, error)
}

func newAppleKeyCache(client *http.Client, ttl time.Duration) *appleKeyCache {
	return &appleKeyCache{
		ttl:   ttl,
		now:   time.Now,
		fetch: func(ctx context.Context) (map[string]*rsa.PublicKey, error) { return fetchAppleKeys(ctx, client) },
	}
}

// get returns the RSA public key for kid, refreshing the cache when it is empty
// or expired. If a fresh fetch fails but stale keys are present, the stale keys
// are used as a fallback (fail-open on availability, not on validity — the JWT
// signature is still verified against a real Apple key). An unknown kid forces a
// single refetch to handle Apple's key rotation.
func (c *appleKeyCache) get(ctx context.Context, kid string) (*rsa.PublicKey, error) {
	c.mu.Lock()
	defer c.mu.Unlock()

	if c.stale() {
		if err := c.refresh(ctx); err != nil {
			if k, ok := c.keys[kid]; ok {
				return k, nil // stale fallback
			}
			return nil, err
		}
	}

	if k, ok := c.keys[kid]; ok {
		return k, nil
	}

	// kid not found — Apple may have rotated keys since our last fetch.
	if err := c.refresh(ctx); err != nil {
		return nil, err
	}
	if k, ok := c.keys[kid]; ok {
		return k, nil
	}
	return nil, fmt.Errorf("apple signing key %q not found", kid)
}

func (c *appleKeyCache) stale() bool {
	return c.keys == nil || c.now().Sub(c.fetchedAt) > c.ttl
}

func (c *appleKeyCache) refresh(ctx context.Context) error {
	keys, err := c.fetch(ctx)
	if err != nil {
		return err
	}
	c.keys = keys
	c.fetchedAt = c.now()
	return nil
}

// fetchAppleKeys retrieves and parses Apple's JWKS using a timeout-bound client.
func fetchAppleKeys(ctx context.Context, client *http.Client) (map[string]*rsa.PublicKey, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, appleKeysURL, nil)
	if err != nil {
		return nil, err
	}
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("apple keys endpoint returned %d", resp.StatusCode)
	}

	var parsed appleKeysResponse
	if err := json.NewDecoder(resp.Body).Decode(&parsed); err != nil {
		return nil, err
	}

	out := make(map[string]*rsa.PublicKey, len(parsed.Keys))
	for _, k := range parsed.Keys {
		pub, err := parseRSAPublicKey(k.N, k.E)
		if err != nil {
			continue // skip unpar-seable keys rather than failing the whole set
		}
		out[k.Kid] = pub
	}
	if len(out) == 0 {
		return nil, fmt.Errorf("apple keys endpoint returned no usable keys")
	}
	return out, nil
}

func parseRSAPublicKey(nStr, eStr string) (*rsa.PublicKey, error) {
	nBytes, err := base64.RawURLEncoding.DecodeString(nStr)
	if err != nil {
		return nil, err
	}
	eBytes, err := base64.RawURLEncoding.DecodeString(eStr)
	if err != nil {
		return nil, err
	}
	return &rsa.PublicKey{
		N: new(big.Int).SetBytes(nBytes),
		E: int(new(big.Int).SetBytes(eBytes).Int64()),
	}, nil
}
