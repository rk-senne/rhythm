// Package web provides small, shared HTTP response helpers so every handler
// returns consistent, correctly-typed JSON. Previously each handler called
// json.NewEncoder(w).Encode(...) without setting Content-Type and silently
// ignored encode errors.
package web

import (
	"encoding/json"
	"log/slog"
	"net/http"
)

// JSON writes v as a JSON response with the given status code and the correct
// Content-Type header. Encoding errors are logged rather than silently dropped.
func JSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	if v == nil {
		return
	}
	if err := json.NewEncoder(w).Encode(v); err != nil {
		// The status/headers are already written, so we cannot change the
		// response; log for observability instead of swallowing the error.
		slog.Error("failed to encode JSON response", "error", err)
	}
}

// Error writes a JSON error body ({"error": "..."}) with the given status code.
// Using a structured body (instead of http.Error's text/plain) lets mobile
// clients parse failures uniformly.
func Error(w http.ResponseWriter, status int, message string) {
	JSON(w, status, map[string]string{"error": message})
}
