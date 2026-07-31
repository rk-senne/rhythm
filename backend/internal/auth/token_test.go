package auth

import (
	"testing"
	"time"
)

const testSecret = "test-secret-please-ignore-0123456789"

func fixedClock(t time.Time) func() time.Time {
	return func() time.Time { return t }
}

func TestIssueAndValidateRoundTrip(t *testing.T) {
	tok, err := issueToken(testSecret, "user-123", TokenTypeAccess, time.Hour, time.Now)
	if err != nil {
		t.Fatalf("issueToken: %v", err)
	}
	claims, err := validateToken(testSecret, tok)
	if err != nil {
		t.Fatalf("validateToken: %v", err)
	}
	if claims.Subject != "user-123" {
		t.Errorf("subject = %q, want user-123", claims.Subject)
	}
	if claims.TokenType != TokenTypeAccess {
		t.Errorf("token_type = %q, want %q", claims.TokenType, TokenTypeAccess)
	}
	if claims.ID == "" {
		t.Error("expected a non-empty jti")
	}
}

func TestValidateRejectsWrongSecret(t *testing.T) {
	tok, err := issueToken(testSecret, "user-123", TokenTypeAccess, time.Hour, time.Now)
	if err != nil {
		t.Fatalf("issueToken: %v", err)
	}
	if _, err := validateToken("a-different-secret", tok); err == nil {
		t.Fatal("expected validation to fail with wrong secret")
	}
}

func TestValidateRejectsExpiredToken(t *testing.T) {
	past := time.Now().Add(-2 * time.Hour)
	tok, err := issueToken(testSecret, "user-123", TokenTypeAccess, time.Hour, fixedClock(past))
	if err != nil {
		t.Fatalf("issueToken: %v", err)
	}
	if _, err := validateToken(testSecret, tok); err == nil {
		t.Fatal("expected validation to fail for expired token")
	}
}

// TestTokenTypeDistinguishesAccessAndRefresh is the regression test for the
// original vulnerability: the refresh endpoint accepted any valid token.
func TestTokenTypeDistinguishesAccessAndRefresh(t *testing.T) {
	access, err := issueToken(testSecret, "u", TokenTypeAccess, time.Hour, time.Now)
	if err != nil {
		t.Fatalf("issueToken access: %v", err)
	}
	refresh, err := issueToken(testSecret, "u", TokenTypeRefresh, time.Hour, time.Now)
	if err != nil {
		t.Fatalf("issueToken refresh: %v", err)
	}

	ac, err := validateToken(testSecret, access)
	if err != nil {
		t.Fatalf("validate access: %v", err)
	}
	rc, err := validateToken(testSecret, refresh)
	if err != nil {
		t.Fatalf("validate refresh: %v", err)
	}
	if ac.TokenType != TokenTypeAccess {
		t.Errorf("access token_type = %q", ac.TokenType)
	}
	if rc.TokenType != TokenTypeRefresh {
		t.Errorf("refresh token_type = %q", rc.TokenType)
	}
	if ac.TokenType == rc.TokenType {
		t.Fatal("access and refresh tokens must have distinct types")
	}
}

func TestNewTokenIDIsUnique(t *testing.T) {
	seen := make(map[string]bool)
	for i := 0; i < 1000; i++ {
		id, err := newTokenID()
		if err != nil {
			t.Fatalf("newTokenID: %v", err)
		}
		if seen[id] {
			t.Fatalf("duplicate token id: %s", id)
		}
		seen[id] = true
	}
}
