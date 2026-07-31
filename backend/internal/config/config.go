package config

import (
	"time"

	"github.com/kelseyhightower/envconfig"
)

type Config struct {
	Port          int    `envconfig:"PORT" default:"8080"`
	DatabaseURL   string `envconfig:"DATABASE_URL" required:"true"`
	RedisURL      string `envconfig:"REDIS_URL" required:"true"`
	JWTSecret     string `envconfig:"JWT_SECRET" required:"true"`
	AppleTeamID   string `envconfig:"APPLE_TEAM_ID" required:"true"`
	AppleBundleID string `envconfig:"APPLE_BUNDLE_ID" required:"true"`

	// APNs push delivery (optional). If these are unset the server runs with a
	// no-op log sender. APNSKeyP8 is the PEM contents of the .p8 provider key.
	APNSKeyID      string `envconfig:"APNS_KEY_ID"`
	APNSKeyP8      string `envconfig:"APNS_KEY_P8"`
	APNSTopic      string `envconfig:"APNS_TOPIC"`
	APNSProduction bool   `envconfig:"APNS_PRODUCTION" default:"false"`

	// AI weekly-summary cost controls. These cap spend on the OpenAI endpoint and
	// are tunable via env without a code change (operability).
	AISummaryRateLimit int           `envconfig:"AI_SUMMARY_RATE_LIMIT" default:"5"`
	AISummaryWindow    time.Duration `envconfig:"AI_SUMMARY_WINDOW" default:"1h"`
}

func Load() (Config, error) {
	var cfg Config
	err := envconfig.Process("", &cfg)
	return cfg, err
}
