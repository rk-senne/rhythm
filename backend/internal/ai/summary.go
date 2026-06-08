package ai

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

type SummaryService struct {
	db *pgxpool.Pool
}

func NewSummaryService(db *pgxpool.Pool) *SummaryService {
	return &SummaryService{db: db}
}

type journalRow struct {
	Text      string    `json:"text"`
	Mood      *string   `json:"mood"`
	CreatedAt time.Time `json:"created_at"`
}

func (s *SummaryService) GenerateWeeklySummary(ctx context.Context, userID string) (string, error) {
	weekAgo := time.Now().AddDate(0, 0, -7)
	rows, err := s.db.Query(ctx,
		`SELECT text, mood, created_at FROM journal_entries 
		 WHERE user_id = $1 AND created_at > $2 ORDER BY created_at`,
		userID, weekAgo,
	)
	if err != nil {
		return "", err
	}
	defer rows.Close()

	var entries []journalRow
	for rows.Next() {
		var e journalRow
		if err := rows.Scan(&e.Text, &e.Mood, &e.CreatedAt); err != nil {
			continue
		}
		entries = append(entries, e)
	}

	if len(entries) == 0 {
		return "No journal entries this week. Start reflecting after your focus sessions!", nil
	}

	return s.callOpenAI(ctx, entries)
}

func (s *SummaryService) callOpenAI(ctx context.Context, entries []journalRow) (string, error) {
	apiKey := os.Getenv("OPENAI_API_KEY")
	if apiKey == "" {
		return "", fmt.Errorf("OPENAI_API_KEY not set")
	}

	entriesJSON, _ := json.Marshal(entries)
	prompt := fmt.Sprintf(`You are a thoughtful productivity coach. Given these journal entries from the past week, write a brief, warm weekly summary (3-5 sentences). Highlight patterns, wins, and gentle suggestions. Keep it under 200 words.

Journal entries:
%s`, string(entriesJSON))

	body := map[string]any{
		"model": "gpt-4o-mini",
		"messages": []map[string]string{
			{"role": "system", "content": "You are a calm, supportive productivity coach."},
			{"role": "user", "content": prompt},
		},
		"max_tokens":  300,
		"temperature": 0.7,
	}

	payload, _ := json.Marshal(body)
	req, _ := http.NewRequestWithContext(ctx, "POST", "https://api.openai.com/v1/chat/completions", bytes.NewReader(payload))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+apiKey)

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	var result struct {
		Choices []struct {
			Message struct {
				Content string `json:"content"`
			} `json:"message"`
		} `json:"choices"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return "", err
	}
	if len(result.Choices) == 0 {
		return "", fmt.Errorf("no response from OpenAI")
	}

	return result.Choices[0].Message.Content, nil
}
