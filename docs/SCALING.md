# Rhythm — Scaling Strategy

**Document Version:** 1.0
**Date:** 29 May 2026
**Status:** Draft

---

## 1. Scaling Philosophy

**Scale when it hurts, not before.** Premature optimization wastes time on problems that may never materialize. The architecture is designed to be simple at small scale and decomposable at large scale.

### Guiding Principles

1. **Vertical first** — Upgrade instance size before adding instances
2. **Measure before optimizing** — Prometheus metrics drive scaling decisions, not guesses
3. **Stateless backend** — Any instance can handle any request (enables horizontal scaling)
4. **Database is the bottleneck** — Optimize queries and add read replicas before sharding
5. **Cache aggressively** — Redis for hot paths, CDN for static content

---

## 2. Infrastructure Tiers

### Tier 1: Launch (0–1K DAU)

```
┌─────────────────────────────────────┐
│           Fly.io (1 instance)       │
│         Go API (256MB RAM)          │
└──────────────────┬──────────────────┘
                   │
        ┌──────────┼──────────┐
        ▼          ▼          ▼
   ┌─────────┐ ┌───────┐ ┌───────┐
   │  Neon   │ │Upstash│ │  R2   │
   │Postgres │ │ Redis │ │(audio)│
   │(free)   │ │(free) │ │(free) │
   └─────────┘ └───────┘ └───────┘
```

| Resource | Spec | Cost |
|----------|------|------|
| Fly.io | 1x shared-cpu-1x, 256MB | $0-5/mo |
| Neon Postgres | Free tier (0.5GB, auto-suspend) | $0 |
| Upstash Redis | Free tier (10K commands/day) | $0 |
| Cloudflare R2 | Free tier (10GB storage) | $0 |
| **Total** | | **$0-5/mo** |

**Handles:** ~500 req/min, ~50 concurrent WebSocket connections

---

### Tier 2: Growth (1K–10K DAU)

```
┌─────────────────────────────────────┐
│      Fly.io (2 instances, 2 regions)│
│       Go API (512MB RAM each)       │
│         + Auto-stop enabled         │
└──────────────────┬──────────────────┘
                   │
        ┌──────────┼──────────┐
        ▼          ▼          ▼
   ┌─────────┐ ┌───────┐ ┌───────┐
   │  Neon   │ │Upstash│ │  R2   │
   │Postgres │ │ Redis │ │(audio)│
   │(Pro)    │ │(Pro)  │ │       │
   └─────────┘ └───────┘ └───────┘
```

| Resource | Spec | Cost |
|----------|------|------|
| Fly.io | 2x shared-cpu-2x, 512MB (iad + ams) | $20-40/mo |
| Neon Postgres | Pro (10GB, always-on, autoscaling) | $19/mo |
| Upstash Redis | Pro (100K commands/day) | $10/mo |
| Cloudflare R2 | ~50GB storage | $1/mo |
| **Total** | | **$50-70/mo** |

**Handles:** ~2,000 req/min, ~500 concurrent connections

**Scaling triggers:**
- P95 latency > 200ms → add instance
- CPU > 70% sustained → upgrade instance size
- DB connections > 80% pool → increase pool or add read replica

---

### Tier 3: Traction (10K–50K DAU)

```
┌─────────────────────────────────────────────┐
│     Fly.io (4-8 instances, 3 regions)       │
│      Go API (1GB RAM each, dedicated CPU)   │
│              Auto-scale enabled              │
└──────────────────────┬──────────────────────┘
                       │
        ┌──────────────┼──────────────┐
        ▼              ▼              ▼
   ┌──────────┐  ┌──────────┐  ┌──────────┐
   │ Neon     │  │ Upstash  │  │    R2    │
   │ Postgres │  │  Redis   │  │  (audio) │
   │ (Scale)  │  │ (Scale)  │  │  500GB   │
   │ +replica │  │ +replica │  │          │
   └──────────┘  └──────────┘  └──────────┘
```

| Resource | Spec | Cost |
|----------|------|------|
| Fly.io | 4-8x performance-2x, 1GB | $150-400/mo |
| Neon Postgres | Scale (50GB, read replicas, branching) | $69/mo |
| Upstash Redis | Enterprise (unlimited, multi-region) | $50/mo |
| Cloudflare R2 | ~500GB | $8/mo |
| Monitoring (Grafana Cloud) | Pro | $30/mo |
| **Total** | | **$300-560/mo** |

**Handles:** ~10,000 req/min, ~5,000 concurrent connections

**New concerns at this tier:**
- Read replicas for analytics queries (don't slow down writes)
- Background job workers separated from API instances
- CDN caching for public API responses (if headless CMS features added)

---

### Tier 4: Scale (50K–200K DAU)

**Migration to AWS EKS** — Fly.io becomes expensive at this scale, and you need more control.

```
┌─────────────────────────────────────────────────────────┐
│                    AWS EKS Cluster                        │
│                                                         │
│  ┌──────────┐  ┌──────────┐  ┌──────────────────────┐  │
│  │ API Pods │  │  Worker  │  │  Push Notification   │  │
│  │ (3-10)   │  │  Pods    │  │  Worker Pods         │  │
│  │ HPA      │  │  (2-4)   │  │  (2-4)              │  │
│  └────┬─────┘  └────┬─────┘  └──────────┬───────────┘  │
│       └──────────────┴───────────────────┘              │
└──────────────────────────┬──────────────────────────────┘
                           │
        ┌──────────────────┼──────────────────┐
        ▼                  ▼                  ▼
   ┌──────────┐     ┌──────────┐      ┌──────────┐
   │ RDS      │     │ElastiCache│     │   S3     │
   │ Postgres │     │  Redis   │      │  (audio) │
   │ Multi-AZ │     │ Cluster  │      │          │
   │ +replicas│     │          │      │          │
   └──────────┘     └──────────┘      └──────────┘
```

| Resource | Spec | Cost |
|----------|------|------|
| EKS cluster | 3 t3.medium nodes (auto-scale to 10) | $200/mo + instances |
| EC2 (nodes) | 3-10x t3.medium | $300-1,000/mo |
| RDS PostgreSQL | db.r6g.large, Multi-AZ, 2 read replicas | $500-800/mo |
| ElastiCache Redis | cache.r6g.large, 2 nodes | $200-400/mo |
| S3 | ~2TB | $50/mo |
| ALB | Application Load Balancer | $30/mo |
| CloudWatch + X-Ray | Monitoring | $50/mo |
| **Total** | | **$1,500-3,000/mo** |

**Handles:** ~50,000 req/min, ~50,000 concurrent WebSocket connections

---

### Tier 5: Platform (200K+ DAU)

At this point, consider:
- Multi-region EKS (US + EU + APAC)
- Global database (CockroachDB or Aurora Global)
- Dedicated push notification service (separate cluster)
- Event-driven architecture (SQS/SNS for decoupling)
- Data warehouse (Redshift/BigQuery) for analytics

**Estimated cost:** $5,000-15,000/mo

---

## 3. Database Scaling Path

### Query Optimization (First Line of Defense)

| Optimization | When | Impact |
|-------------|------|--------|
| Add indexes on `user_id + created_at` | Day 1 | 10-100x faster queries |
| Connection pooling (PgBouncer) | >100 connections | Reduces DB load |
| Query result caching (Redis) | >1K DAU | 80% fewer DB reads |
| Prepared statements | Always | Faster repeated queries |

### Read Replicas (Second Line)

```
Writes ──▶ Primary ──▶ Replica 1 (analytics)
                   ──▶ Replica 2 (sync reads)
```

- Sync pull queries → read replica
- Analytics/AI queries → dedicated replica
- Writes always go to primary

### Partitioning (Third Line)

Journal entries and hydration logs are append-only and time-series in nature:

```sql
-- Partition journal_entries by month
CREATE TABLE journal_entries (
    id UUID,
    user_id UUID,
    created_at TIMESTAMPTZ,
    ...
) PARTITION BY RANGE (created_at);

CREATE TABLE journal_entries_2026_06
    PARTITION OF journal_entries
    FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');
```

Benefits:
- Faster queries (only scan relevant partitions)
- Easy archival (detach old partitions)
- Parallel vacuum/analyze

### Sharding (Last Resort, >1M users)

If needed, shard by `user_id`:
- Each shard holds ~100K users
- Routing layer maps user_id → shard
- Consider Citus (PostgreSQL extension) before custom sharding

---

## 4. Go Backend Scaling

### Why Go Scales Well for This Workload

| Workload | Go Advantage |
|----------|-------------|
| Push notification fanout | 100K goroutines dispatching APNs calls concurrently |
| Calendar sync (background) | 10K users syncing simultaneously, ~50MB memory |
| WebSocket (team features) | 50K connections per instance, minimal per-connection overhead |
| JSON serialization | stdlib encoding/json is fast enough; switch to sonic if needed |
| Cold start | <100ms (important for Fly.io auto-scale) |

### Horizontal Scaling Strategy

```
                    ┌─────────────┐
                    │ Load Balancer│
                    └──────┬──────┘
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
         ┌────────┐  ┌────────┐  ┌────────┐
         │ API-1  │  │ API-2  │  │ API-3  │
         └────────┘  └────────┘  └────────┘
              │            │            │
              └────────────┼────────────┘
                           │
                    ┌──────┴──────┐
                    │  Shared DB  │
                    │  + Redis    │
                    └─────────────┘
```

All instances are stateless. Session state lives in Redis. Any instance can handle any request.

### Worker Separation

At Tier 3+, separate API servers from background workers:

| Process | Responsibility | Scaling |
|---------|---------------|---------|
| API server | HTTP requests, sync, auth | Scale by request volume |
| Push worker | Notification dispatch | Scale by notification queue depth |
| Calendar worker | OAuth token refresh, event sync | Scale by connected accounts |
| AI worker | Weekly summary generation | Scale by paid user count |

---

## 5. iOS Client Scaling Considerations

The iOS app doesn't "scale" in the traditional sense, but performance matters:

| Concern | Solution |
|---------|----------|
| SwiftData with 10K+ journal entries | Fetch with predicates + limits, never load all |
| Timeline rendering (many cycles) | LazyVStack, only render visible cells |
| Background sync with large datasets | Batch sync (100 records per push), delta only |
| Widget updates | WidgetKit timeline provider, max 15-min refresh |
| Watch communication | Prioritize recent data, don't sync full history |
| Voice memo storage | Compress audio (AAC, 64kbps), upload async |

---

## 6. Caching Strategy

### Cache Layers

```
Request → CDN Cache → Redis Cache → Database
```

| Layer | What's Cached | TTL | Invalidation |
|-------|--------------|-----|-------------|
| **CDN (Cloudflare)** | Public API responses, marketing site | 5 min | Purge on deploy |
| **Redis (hot)** | User settings, active cycle state, rate limit counters | 5-60 min | Write-through |
| **Redis (warm)** | Calendar events, team focus status | 15 min | TTL expiry |
| **Application** | JWT validation (public key), config | Process lifetime | Restart |

### Cache Hit Rate Targets

| Endpoint | Target Hit Rate |
|----------|----------------|
| GET /sync/pull (no changes) | 80% (304 Not Modified) |
| GET /calendar/events | 70% (events don't change often) |
| GET /teams/:id/focus | 90% (read-heavy, write-rare) |
| POST /sync/push | 0% (always write-through) |

---

## 7. Monitoring & Alerting

### Key Metrics to Watch

| Metric | Warning | Critical | Action |
|--------|---------|----------|--------|
| P95 API latency | >200ms | >500ms | Scale up / optimize query |
| Error rate (5xx) | >1% | >5% | Investigate immediately |
| DB connection pool usage | >70% | >90% | Increase pool / add replica |
| Redis memory | >70% | >85% | Evict cold keys / upgrade |
| Push delivery rate | <95% | <90% | Check APNs connection |
| Sync queue depth | >1,000 | >10,000 | Add worker instances |
| CPU (per instance) | >70% | >85% | Auto-scale trigger |
| Memory (per instance) | >80% | >90% | Investigate leak / scale |

### Dashboards

1. **Overview** — Request rate, error rate, latency percentiles
2. **Database** — Query duration, connection pool, replication lag
3. **Push Notifications** — Sent/delivered/failed, queue depth
4. **Business** — DAU, cycles completed, sync operations, paid conversions

---

## 8. Disaster Recovery

| Scenario | RTO | RPO | Strategy |
|----------|-----|-----|----------|
| Single instance crash | 30s | 0 | Fly.io auto-restart, health checks |
| Region outage | 5 min | 0 | Multi-region deployment, DNS failover |
| Database corruption | 1 hour | 5 min | Point-in-time recovery (Neon/RDS) |
| Complete data loss | 4 hours | 24 hours | Daily backups to separate region |
| DDoS attack | 0 (mitigated) | 0 | Cloudflare DDoS protection |

### Backup Strategy

| Data | Frequency | Retention | Location |
|------|-----------|-----------|----------|
| PostgreSQL (full) | Daily | 30 days | Separate region (R2/S3) |
| PostgreSQL (WAL) | Continuous | 7 days | Same provider |
| Redis (RDB) | Hourly | 24 hours | Ephemeral (rebuildable) |
| Voice memos (R2) | N/A (durable storage) | Indefinite | Multi-region replication |

---

## 9. Cost Optimization

| Strategy | Savings | When to Apply |
|----------|---------|---------------|
| Fly.io auto-stop (scale to zero at night) | 40-60% | Phase 1-2 |
| Neon auto-suspend (pause when idle) | 50-70% | Phase 1 |
| Reserved instances (AWS) | 30-40% | Phase 4+ (predictable load) |
| Spot instances for workers | 60-70% | Phase 4+ (interruptible jobs) |
| CDN caching (reduce origin hits) | 20-30% on compute | Phase 2+ |
| Compress voice memos before upload | 50% on storage | Always |
| Batch AI requests (weekly, not real-time) | 80% on OpenAI costs | Always |
