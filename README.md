# Rhythm

A calm-productivity iOS app that structures your workday around your body's natural **ultradian rhythm** (90–120 minute cycles). Each cycle flows through a focused work session, a guided transition ritual (breathe → hydrate → reflect), and a brief preparation step for what's next.

## Repository Layout

```
backend/     Go 1.22 API — auth, sync, AI weekly summaries (chi + PostgreSQL + Redis)
ios/         SwiftUI + TCA (The Composable Architecture) app, Watch app, Widgets
docs/        Product specs, architecture docs, setup guides, business analysis
.github/     CI workflows (GitHub Actions)
```

## Getting Started

### Backend

Prerequisites: Go 1.22+, Docker & Docker Compose.

```bash
cd backend

# Start Postgres + Redis
docker compose up -d

# Copy environment config
cp .env.example .env

# Download dependencies
go mod tidy

# Run the server (auto-runs migrations)
go run ./cmd/server
```

Verify: `curl http://localhost:8080/health` → `ok`

#### Testing

```bash
make test     # Fast, hermetic unit tests (no external services)
make itest    # Integration tests against ephemeral Postgres + Redis
make vet      # go vet
```

See [`backend/README.md`](backend/README.md) for endpoint documentation.

### iOS

Prerequisites: Xcode 15+, [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
cd ios/Rhythm

# Generate the Xcode project from project.yml
xcodegen generate

# Build
xcodebuild -project Rhythm.xcodeproj -scheme Rhythm -sdk iphonesimulator build

# Run tests
xcodebuild -project Rhythm.xcodeproj -scheme Rhythm -sdk iphonesimulator test
```

> **Note:** `project.yml` is the source of truth — never hand-edit `Rhythm.xcodeproj`.

See [`docs/XCODE_SETUP.md`](docs/XCODE_SETUP.md) for signing, capabilities, and full setup instructions.

## Key Documentation

| Document | Description |
|----------|-------------|
| [Spec & Roadmap](docs/SPEC_AND_ROADMAP.md) | Product specification and feature roadmap |
| [System Architecture](docs/SYSTEM_ARCHITECTURE.md) | End-to-end architecture and data flow |
| [Tech Stack](docs/TECH_STACK.md) | Technology choices and rationale |
| [Technical Plan](docs/TECHNICAL_PLAN.md) | Implementation plan and milestones |
| [UX/UI Design](docs/UX_UI_DESIGN.md) | Design system and interaction patterns |
| [Xcode Setup](docs/XCODE_SETUP.md) | iOS project generation and configuration |
| [Deployment](docs/DEPLOYMENT.md) | Backend deployment (Fly.io) and release process |
| [Scaling](docs/SCALING.md) | Scaling strategy (Fly.io → AWS EKS) |

## License

Private repository. All rights reserved.
