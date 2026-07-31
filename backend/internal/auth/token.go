package auth

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// Token types. Access tokens authorize API calls; refresh tokens may only be
// exchanged at /auth/refresh. Keeping them distinct closes the vulnerability
// where any valid token (including a long-lived... short-lived access token)
// could be replayed against the refresh endpoint.
const (
	TokenTypeAccess  = "access"
	TokenTypeRefresh = "refresh"
)

// Claims is the JWT payload. TokenType distinguishes access vs refresh tokens.
// The JTI (ID) gives every token a unique identifier, enabling future
// revocation via a Redis denylist without changing the token format.
type Claims struct {
	TokenType string `json:"token_type"`
	jwt.RegisteredClaims
}

// issueToken mints a signed HS256 token for the subject with the given type and
// lifetime. now is injected so tests can produce already-expired tokens.
func issueToken(secret, subject, tokenType string, expiry time.Duration, now func() time.Time) (string, error) {
	jti, err := newTokenID()
	if err != nil {
		return "", err
	}
	issued := now()
	claims := Claims{
		TokenType: tokenType,
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   subject,
			IssuedAt:  jwt.NewNumericDate(issued),
			ExpiresAt: jwt.NewNumericDate(issued.Add(expiry)),
			Issuer:    tokenIssuer,
			ID:        jti,
		},
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(secret))
}

// validateToken parses and verifies a token's signature, algorithm, and expiry.
// It rejects any non-HMAC signing method (algorithm-confusion defense).
func validateToken(secret, tokenStr string) (*Claims, error) {
	var claims Claims
	token, err := jwt.ParseWithClaims(tokenStr, &claims, func(t *jwt.Token) (any, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", t.Header["alg"])
		}
		return []byte(secret), nil
	}, jwt.WithValidMethods([]string{"HS256"}))
	if err != nil {
		return nil, err
	}
	if !token.Valid {
		return nil, fmt.Errorf("token invalid")
	}
	return &claims, nil
}

const tokenIssuer = "rhythm-api"

// newTokenID returns a random 128-bit hex identifier for the JWT ID (jti).
func newTokenID() (string, error) {
	b := make([]byte, 16)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return hex.EncodeToString(b), nil
}
