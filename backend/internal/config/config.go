package config

import "github.com/kelseyhightower/envconfig"

type Config struct {
	Port        int    `envconfig:"PORT" default:"8080"`
	DatabaseURL string `envconfig:"DATABASE_URL" required:"true"`
	RedisURL    string `envconfig:"REDIS_URL" required:"true"`
	JWTSecret   string `envconfig:"JWT_SECRET" required:"true"`
	AppleTeamID string `envconfig:"APPLE_TEAM_ID" required:"true"`
	AppleBundleID string `envconfig:"APPLE_BUNDLE_ID" required:"true"`
}

func Load() (Config, error) {
	var cfg Config
	err := envconfig.Process("", &cfg)
	return cfg, err
}
