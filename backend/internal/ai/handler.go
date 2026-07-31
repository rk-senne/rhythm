package ai

import (
	"errors"
	"net/http"

	"github.com/rhythm-app/rhythm-api/internal/auth"
	"github.com/rhythm-app/rhythm-api/internal/web"
)

type Handler struct {
	service *SummaryService
}

func NewHandler(service *SummaryService) *Handler {
	return &Handler{service: service}
}

func (h *Handler) GetWeeklySummary(w http.ResponseWriter, r *http.Request) {
	userID, ok := r.Context().Value(auth.UserIDKey).(string)
	if !ok || userID == "" {
		web.Error(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	summary, err := h.service.GenerateWeeklySummary(r.Context(), userID)
	if err != nil {
		if errors.Is(err, ErrRateLimited) {
			web.Error(w, http.StatusTooManyRequests, "weekly summary already generated recently; try again later")
			return
		}
		web.Error(w, http.StatusInternalServerError, "failed to generate summary")
		return
	}

	web.JSON(w, http.StatusOK, map[string]string{"summary": summary})
}
