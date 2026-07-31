package ai

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"time"
)

const (
	openAIURL     = "https://api.openai.com/v1/chat/completions"
	openAITimeout = 30 * time.Second
	defaultModel  = "gpt-4o-mini"
)

// OpenAISummarizer implements Summarizer using OpenAI's chat completions API.
type OpenAISummarizer struct {
	apiKey string
	model  string
	client *http.Client
}

func NewOpenAISummarizer(apiKey string) *OpenAISummarizer {
	return &OpenAISummarizer{
		apiKey: apiKey,
		model:  defaultModel,
		client: &http.Client{Timeout: openAITimeout},
	}
}

func (o *OpenAISummarizer) Summarize(ctx context.Context, entries []JournalEntry) (string, error) {
	if o.apiKey == "" {
		return "", fmt.Errorf("OPENAI_API_KEY not set")
	}

	entriesJSON, err := json.Marshal(entries)
	if err != nil {
		return "", err
	}
	prompt := fmt.Sprintf(`You are a thoughtful productivity coach. Given these journal entries from the past week, write a brief, warm weekly summary (3-5 sentences). Highlight patterns, wins, and gentle suggestions. Keep it under 200 words.

Journal entries:
%s`, string(entriesJSON))

	reqBody := map[string]any{
		"model": o.model,
		"messages": []map[string]string{
			{"role": "system", "content": "You are a calm, supportive productivity coach."},
			{"role": "user", "content": prompt},
		},
		"max_tokens":  300,
		"temperature": 0.7,
	}
	payload, err := json.Marshal(reqBody)
	if err != nil {
		return "", err
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, openAIURL, bytes.NewReader(payload))
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+o.apiKey)

	resp, err := o.client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("openai returned status %d", resp.StatusCode)
	}

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
