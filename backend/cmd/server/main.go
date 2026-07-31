package main

import (
	"context"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/httprate"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"

	"github.com/rhythm-app/rhythm-api/internal/ai"
	"github.com/rhythm-app/rhythm-api/internal/auth"
	"github.com/rhythm-app/rhythm-api/internal/config"
	"github.com/rhythm-app/rhythm-api/internal/push"
	"github.com/rhythm-app/rhythm-api/internal/storage"
	"github.com/rhythm-app/rhythm-api/internal/sync"
	"github.com/rhythm-app/rhythm-api/internal/web"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		slog.Error("failed to load config", "error", err)
		os.Exit(1)
	}

	// rootCtx is cancelled on shutdown so background workers stop cleanly.
	rootCtx, cancel := context.WithCancel(context.Background())
	defer cancel()

	db, err := storage.NewPostgres(rootCtx, cfg.DatabaseURL)
	if err != nil {
		slog.Error("failed to connect postgres", "error", err)
		os.Exit(1)
	}
	defer db.Close()

	if err := storage.RunMigrations(cfg.DatabaseURL); err != nil {
		slog.Error("failed to run migrations", "error", err)
		os.Exit(1)
	}

	rdb := storage.NewRedis(cfg.RedisURL)
	defer rdb.Close()

	// Start the push worker with a real APNs sender when configured, else a
	// no-op log sender so the server still runs in development.
	worker := push.NewWorker(rdb, buildPushSender(cfg))
	go worker.Run(rootCtx)

	authService := auth.NewService(cfg, auth.WithDenylist(auth.NewRedisDenylist(rdb)))
	syncHandler := sync.NewHandler(sync.NewPgStore(db))
	aiHandler := ai.NewHandler(ai.NewSummaryService(
		ai.NewPgJournalStore(db),
		ai.NewOpenAISummarizer(os.Getenv("OPENAI_API_KEY")),
		ai.NewRedisRateLimiter(rdb, cfg.AISummaryRateLimit, cfg.AISummaryWindow), // cost cap: tunable via env
		ai.NewRedisCache(rdb),
	))

	r := chi.NewRouter()
	r.Use(middleware.RequestID)
	r.Use(middleware.RealIP)
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)
	r.Use(httprate.LimitByIP(100, time.Minute))

	// Liveness: process is up. Kept as a plain 200 for existing platform checks.
	r.Get("/health", func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})
	// Readiness: dependencies are reachable.
	r.Get("/ready", readyHandler(db, rdb))

	r.Route("/auth", func(r chi.Router) {
		r.Use(httprate.LimitByIP(20, time.Minute)) // tighter guard on the auth surface
		r.Use(middleware.Timeout(15 * time.Second))
		r.Post("/apple", authService.HandleAppleSignIn)
		r.Post("/refresh", authService.HandleRefresh)
	})

	r.Route("/sync", func(r chi.Router) {
		r.Use(authService.Middleware)
		r.Use(middleware.Timeout(15 * time.Second))
		r.Post("/push", syncHandler.Push)
		r.Get("/pull", syncHandler.Pull)
	})

	r.Route("/ai", func(r chi.Router) {
		r.Use(authService.Middleware)
		r.Use(httprate.LimitByIP(10, time.Minute))
		r.Use(middleware.Timeout(35 * time.Second)) // OpenAI calls can be slow
		r.Get("/weekly-summary", aiHandler.GetWeeklySummary)
	})

	srv := &http.Server{
		Addr:              fmt.Sprintf(":%d", cfg.Port),
		Handler:           r,
		ReadHeaderTimeout: 10 * time.Second, // slow-loris guard
	}

	go func() {
		slog.Info("server starting", "port", cfg.Port)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			slog.Error("server error", "error", err)
			os.Exit(1)
		}
	}()

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt, syscall.SIGTERM)
	<-stop
	slog.Info("shutdown signal received")

	cancel() // stop background workers

	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer shutdownCancel()
	if err := srv.Shutdown(shutdownCtx); err != nil {
		slog.Error("graceful shutdown failed", "error", err)
	}
	slog.Info("server stopped")
}

// buildPushSender returns a real APNs sender when APNs is configured, otherwise
// a no-op log sender so the server still runs in development without creds.
func buildPushSender(cfg config.Config) push.Sender {
	if cfg.APNSKeyP8 == "" || cfg.APNSKeyID == "" || cfg.AppleTeamID == "" || cfg.APNSTopic == "" {
		slog.Warn("APNs not configured; push notifications will be logged, not delivered")
		return push.LogSender{}
	}
	provider, err := push.NewES256TokenProvider(cfg.AppleTeamID, cfg.APNSKeyID, []byte(cfg.APNSKeyP8))
	if err != nil {
		slog.Error("APNs provider key invalid; falling back to log sender", "error", err)
		return push.LogSender{}
	}
	slog.Info("APNs push enabled", "production", cfg.APNSProduction, "topic", cfg.APNSTopic)
	return push.NewAPNsSender(push.APNsBaseURL(cfg.APNSProduction), cfg.APNSTopic, provider)
}

// readyHandler verifies Postgres and Redis are reachable before reporting ready.
func readyHandler(db *pgxpool.Pool, rdb *redis.Client) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
		defer cancel()

		if err := db.Ping(ctx); err != nil {
			web.JSON(w, http.StatusServiceUnavailable, map[string]string{"status": "degraded", "postgres": "unreachable"})
			return
		}
		if err := rdb.Ping(ctx).Err(); err != nil {
			web.JSON(w, http.StatusServiceUnavailable, map[string]string{"status": "degraded", "redis": "unreachable"})
			return
		}
		web.JSON(w, http.StatusOK, map[string]string{"status": "ok"})
	}
}
