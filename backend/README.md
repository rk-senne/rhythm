# Rhythm Backend

## Local Development

### Prerequisites
- Go 1.22+
- Docker & Docker Compose

### Setup
```bash
# Start Postgres + Redis
docker compose up -d

# Copy env vars
cp .env.example .env

# Download dependencies
go mod tidy

# Run server (auto-runs migrations)
go run ./cmd/server
```

### Verify
```bash
curl http://localhost:8080/health
# → ok
```

### Endpoints
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | /health | No | Health check |
| POST | /auth/apple | No | Exchange Apple identity token for JWT |
| POST | /auth/refresh | No | Refresh access token |
| POST | /sync/push | Yes | Push local changes to server |
| GET | /sync/pull?since=RFC3339 | Yes | Pull changes since timestamp |
