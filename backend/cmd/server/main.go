package main

import (
	"context"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/httprate"
	"github.com/rhythm-app/rhythm-api/internal/auth"
	"github.com/rhythm-app/rhythm-api/internal/config"
	"github.com/rhythm-app/rhythm-api/internal/storage"
	"github.com/rhythm-app/rhythm-api/internal/sync"
	"github.com/rhythm-app/rhythm-api/internal/ai"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		slog.Error("failed to load config", "error", err)
		os.Exit(1)
	}

	db, err := storage.NewPostgres(context.Background(), cfg.DatabaseURL)
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

	authService := auth.NewService(cfg)
	syncHandler := sync.NewHandler(db)
	aiHandler := ai.NewHandler(ai.NewSummaryService(db))

	r := chi.NewRouter()
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)
	r.Use(middleware.RealIP)
	r.Use(httprate.LimitByIP(100, time.Minute))

	r.Get("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("ok"))
	})

	r.Route("/auth", func(r chi.Router) {
		r.Post("/apple", authService.HandleAppleSignIn)
		r.Post("/refresh", authService.HandleRefresh)
	})

	r.Route("/sync", func(r chi.Router) {
		r.Use(authService.Middleware)
		r.Post("/push", syncHandler.Push)
		r.Get("/pull", syncHandler.Pull)
	})

	r.Route("/ai", func(r chi.Router) {
		r.Use(authService.Middleware)
		r.Get("/weekly-summary", aiHandler.GetWeeklySummary)
	})

	srv := &http.Server{
		Addr:    fmt.Sprintf(":%d", cfg.Port),
		Handler: r,
	}

	go func() {
		slog.Info("server starting", "port", cfg.Port)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			slog.Error("server error", "error", err)
			os.Exit(1)
		}
	}()

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt)
	<-stop

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	srv.Shutdown(ctx)
	slog.Info("server stopped")
}
