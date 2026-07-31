package auth

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/rhythm-app/rhythm-api/internal/config"
	"github.com/rhythm-app/rhythm-api/internal/web"
)

type contextKey string

const UserIDKey contextKey = "user_id"

// Token lifetimes.
const (
	accessTokenTTL  = 15 * time.Minute
	refreshTokenTTL = 30 * 24 * time.Hour
	appleKeyTTL     = 6 * time.Hour
	httpTimeout     = 10 * time.Second
)

type Service struct {
	cfg        config.Config
	httpClient *http.Client
	appleKeys  *appleKeyCache
	now        func() time.Time
	denylist   Denylist
}

// Option configures a Service.
type Option func(*Service)

// WithDenylist enables refresh-token revocation / reuse detection.
func WithDenylist(d Denylist) Option {
	return func(s *Service) {
		if d != nil {
			s.denylist = d
		}
	}
}

func NewService(cfg config.Config, opts ...Option) *Service {
	client := &http.Client{Timeout: httpTimeout}
	s := &Service{
		cfg:        cfg,
		httpClient: client,
		appleKeys:  newAppleKeyCache(client, appleKeyTTL),
		now:        time.Now,
		denylist:   NoopDenylist{},
	}
	for _, opt := range opts {
		opt(s)
	}
	return s
}

type appleTokenRequest struct {
	IdentityToken string `json:"identity_token"`
}

type tokenResponse struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token,omitempty"`
	ExpiresIn    int    `json:"expires_in"`
}

func (s *Service) HandleAppleSignIn(w http.ResponseWriter, r *http.Request) {
	var req appleTokenRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		web.Error(w, http.StatusBadRequest, "invalid request")
		return
	}

	claims, err := s.verifyAppleToken(r.Context(), req.IdentityToken)
	if err != nil {
		web.Error(w, http.StatusUnauthorized, "invalid identity token")
		return
	}

	sub, _ := claims.GetSubject()
	access, refresh, err := s.issuePair(sub)
	if err != nil {
		web.Error(w, http.StatusInternalServerError, "token generation failed")
		return
	}

	web.JSON(w, http.StatusOK, tokenResponse{
		AccessToken:  access,
		RefreshToken: refresh,
		ExpiresIn:    int(accessTokenTTL.Seconds()),
	})
}

func (s *Service) HandleRefresh(w http.ResponseWriter, r *http.Request) {
	var body struct {
		RefreshToken string `json:"refresh_token"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		web.Error(w, http.StatusBadRequest, "invalid request")
		return
	}

	claims, err := validateToken(s.cfg.JWTSecret, body.RefreshToken)
	if err != nil {
		web.Error(w, http.StatusUnauthorized, "invalid refresh token")
		return
	}
	// Critical: only refresh tokens may be exchanged here. An access token
	// presented at this endpoint must be rejected.
	if claims.TokenType != TokenTypeRefresh {
		web.Error(w, http.StatusUnauthorized, "not a refresh token")
		return
	}

	// Reuse detection: reject a refresh token that has already been rotated or
	// revoked. With deny-on-rotate below, refresh tokens become single-use, so a
	// stolen/replayed copy is rejected once the legitimate client has refreshed.
	if denied, err := s.denylist.IsDenied(r.Context(), claims.ID); err == nil && denied {
		web.Error(w, http.StatusUnauthorized, "refresh token no longer valid")
		return
	}

	// Rotate: revoke the presented refresh token for its remaining lifetime.
	if claims.ExpiresAt != nil {
		if ttl := time.Until(claims.ExpiresAt.Time); ttl > 0 {
			_ = s.denylist.Deny(r.Context(), claims.ID, ttl)
		}
	}

	// Rotate: issue a new refresh token alongside the access token so a leaked
	// refresh token has a bounded useful life once the user is active again.
	access, refresh, err := s.issuePair(claims.Subject)
	if err != nil {
		web.Error(w, http.StatusInternalServerError, "token generation failed")
		return
	}

	web.JSON(w, http.StatusOK, tokenResponse{
		AccessToken:  access,
		RefreshToken: refresh,
		ExpiresIn:    int(accessTokenTTL.Seconds()),
	})
}

func (s *Service) Middleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		authz := r.Header.Get("Authorization")
		if !strings.HasPrefix(authz, "Bearer ") {
			web.Error(w, http.StatusUnauthorized, "unauthorized")
			return
		}

		claims, err := validateToken(s.cfg.JWTSecret, strings.TrimPrefix(authz, "Bearer "))
		if err != nil {
			web.Error(w, http.StatusUnauthorized, "unauthorized")
			return
		}
		// Only access tokens authorize API calls; refresh tokens must not.
		if claims.TokenType != TokenTypeAccess {
			web.Error(w, http.StatusUnauthorized, "access token required")
			return
		}

		ctx := context.WithValue(r.Context(), UserIDKey, claims.Subject)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

// issuePair mints a fresh access + refresh token for a subject.
func (s *Service) issuePair(subject string) (access, refresh string, err error) {
	access, err = issueToken(s.cfg.JWTSecret, subject, TokenTypeAccess, accessTokenTTL, s.now)
	if err != nil {
		return "", "", err
	}
	refresh, err = issueToken(s.cfg.JWTSecret, subject, TokenTypeRefresh, refreshTokenTTL, s.now)
	if err != nil {
		return "", "", err
	}
	return access, refresh, nil
}

// verifyAppleToken validates an Apple identity token against Apple's cached
// public keys and checks issuer/audience.
func (s *Service) verifyAppleToken(ctx context.Context, tokenStr string) (jwt.Claims, error) {
	token, err := jwt.Parse(tokenStr, func(t *jwt.Token) (any, error) {
		kid, ok := t.Header["kid"].(string)
		if !ok {
			return nil, fmt.Errorf("missing kid header")
		}
		return s.appleKeys.get(ctx, kid)
	}, jwt.WithValidMethods([]string{"RS256"}))
	if err != nil {
		return nil, err
	}

	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		return nil, fmt.Errorf("invalid claims")
	}

	iss, _ := claims.GetIssuer()
	if iss != "https://appleid.apple.com" {
		return nil, fmt.Errorf("invalid issuer")
	}
	aud, _ := claims.GetAudience()
	if !contains(aud, s.cfg.AppleBundleID) {
		return nil, fmt.Errorf("invalid audience")
	}
	return claims, nil
}

func contains(slice []string, item string) bool {
	for _, s := range slice {
		if s == item {
			return true
		}
	}
	return false
}
