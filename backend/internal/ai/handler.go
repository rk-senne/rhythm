package ai

import (
	"encoding/json"
	"net/http"

	"github.com/rhythm-app/rhythm-api/internal/auth"
)

type Handler struct {
	service *SummaryService
}

func NewHandler(service *SummaryService) *Handler {
	return &Handler{service: service}
}

func (h *Handler) GetWeeklySummary(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value(auth.UserIDKey).(string)

	summary, err := h.service.GenerateWeeklySummary(r.Context(), userID)
	if err != nil {
		http.Error(w, "failed to generate summary", http.StatusInternalServerError)
		return
	}

	json.NewEncoder(w).Encode(map[string]string{"summary": summary})
}
