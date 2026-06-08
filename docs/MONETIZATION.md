# Rhythm — Monetization Strategy

**Document Version:** 1.0
**Date:** 29 May 2026
**Status:** Draft

---

## 1. Pricing Model

### Tier Structure

| Tier | Price | Billing | Target |
|------|-------|---------|--------|
| **Free** | $0 | — | Acquisition + habit formation |
| **Pro** | $4.99/mo | Monthly | Users who want flexibility |
| **Pro** | $39.99/yr | Annual | Power users (33% discount incentive) |
| **Team** | $7.99/user/mo | Monthly | Teams of 5+ |
| **Team** | $69.99/user/yr | Annual | Enterprise-adjacent |

### Feature Gating

| Feature | Free | Pro | Team |
|---------|------|-----|------|
| Focus cycles per day | 2 | Unlimited | Unlimited |
| Timer durations | 45, 60, 90 min | Custom (15-120 min) | Custom |
| Transition ritual | ✓ | ✓ | ✓ |
| Hydration tracking | ✓ | ✓ | ✓ |
| Micro-journal (text) | ✓ | ✓ | ✓ |
| Voice journal | ✗ | ✓ | ✓ |
| Apple Watch app | ✗ | ✓ | ✓ |
| Widgets | Basic (1 type) | All widgets | All widgets |
| Calendar integration | View only | Full (auto-schedule) | Full |
| AI weekly summary | ✗ | ✓ | ✓ |
| AI Coach | ✗ | ✓ | ✓ |
| Journal export (PDF) | ✗ | ✓ | ✓ |
| Shared focus hours | ✗ | ✗ | ✓ |
| Slack integration | ✗ | ✗ | ✓ |
| Team analytics | ✗ | ✗ | ✓ |
| Priority support | ✗ | ✓ | ✓ |

### Why This Gating

- **Free tier is generous enough to form the habit** — 2 cycles/day covers a casual user. They feel the value before hitting the wall.
- **Watch is Pro-only** — Watch users are power users with high willingness to pay. This is the #1 conversion driver.
- **AI features are Pro-only** — Ongoing cost to serve, justifies subscription.
- **Team features are separate tier** — Different buyer (manager/company), different value prop.

---

## 2. Revenue Projections

### Assumptions

| Metric | Value | Source |
|--------|-------|--------|
| Free→Paid conversion | 5% | Industry avg for wellness apps (3-7%) |
| Annual vs Monthly split | 80% annual / 20% monthly | Typical for well-positioned paywall |
| Monthly churn (monthly subs) | 15% | Conservative for wellness |
| Annual churn | 8% | Lower due to commitment |
| Average revenue per paid user | $3.33/mo | Blended (annual + monthly) |

### Month-by-Month Projection

| Month | Cumulative Downloads | DAU | Paid Users | MRR | Notes |
|-------|---------------------|-----|-----------|-----|-------|
| 1 | 500 | 100 | 0 | $0 | Beta only |
| 2 | 1,000 | 200 | 0 | $0 | Beta only |
| 3 | 2,500 | 500 | 25 | $100 | App Store launch |
| 4 | 5,000 | 1,000 | 50 | $200 | Post-launch growth |
| 5 | 8,000 | 1,500 | 75 | $300 | Organic + ASO |
| 6 | 12,000 | 2,200 | 110 | $440 | Paid ads begin |
| 7 | 18,000 | 3,000 | 180 | $720 | Influencer push |
| 8 | 25,000 | 4,000 | 250 | $1,000 | Team tier launches |
| 9 | 35,000 | 5,500 | 350 | $1,400 | |
| 10 | 48,000 | 7,500 | 500 | $2,000 | |
| 11 | 62,000 | 9,500 | 650 | $2,600 | |
| 12 | 80,000 | 12,000 | 800 | $3,200 | Year 1 target |

### Year 2 Projection (If Growth Continues)

| Month | DAU | Paid Users | MRR |
|-------|-----|-----------|-----|
| 15 | 20,000 | 1,500 | $6,000 |
| 18 | 30,000 | 2,500 | $10,000 |
| 21 | 45,000 | 4,000 | $16,000 |
| 24 | 60,000 | 6,000 | $24,000 |

**Year 2 ARR:** ~$288,000

---

## 3. Cost Structure

### Fixed Costs (Monthly)

| Item | Phase 1-2 | Phase 3 | Phase 4 |
|------|-----------|---------|---------|
| Apple Developer Program | $8 | $8 | $8 |
| Fly.io hosting | $5-15 | $50-150 | $300-800 |
| Neon PostgreSQL | $0 (free tier) | $19 | $69 |
| Upstash Redis | $0 (free tier) | $10 | $50 |
| Cloudflare R2 | $0 (free tier) | $5 | $30 |
| Domain + DNS | $2 | $2 | $2 |
| **Total fixed** | **$15-25** | **$94-194** | **$459-959** |

### Variable Costs (Per User/Month)

| Item | Cost | Notes |
|------|------|-------|
| OpenAI API (weekly summary) | $0.01-0.05/user | ~500 tokens per summary |
| Push notifications (APNs) | $0 | Free from Apple |
| Voice memo storage (R2) | $0.001/user | ~5MB/user/month |
| RevenueCat | 1% of revenue | Free <$2.5K MRR |
| **Total variable** | **~$0.03-0.06/user** | |

### Unit Economics

| Metric | Value |
|--------|-------|
| ARPU (paid, monthly) | $3.33 |
| Cost to serve (paid user) | $0.06 |
| Gross margin | 98% |
| CAC (blended) | $2.50 |
| LTV (annual subscriber, 2yr avg retention) | $67 |
| LTV:CAC ratio | 27:1 |

---

## 4. Paywall Strategy

### When to Show

- **Not on first launch** — Let users complete their first cycle. Feel the value.
- **After 3rd cycle** — "You've completed 3 cycles! Unlock unlimited with Pro."
- **When hitting free limit** — "You've used your 2 free cycles today. Start fresh tomorrow, or go Pro."
- **Feature discovery** — Tapping Watch setup, voice journal, or AI summary shows soft paywall.

### Paywall Design

```
┌─────────────────────────────────────┐
│                                     │
│     Unlock your full rhythm         │
│                                     │
│  ┌───────────────────────────────┐  │
│  │ ✓ Unlimited focus cycles      │  │
│  │ ✓ Apple Watch app             │  │
│  │ ✓ Voice journaling            │  │
│  │ ✓ Calendar auto-scheduling    │  │
│  │ ✓ AI weekly insights          │  │
│  │ ✓ All widgets                 │  │
│  └───────────────────────────────┘  │
│                                     │
│  ┌─────────────────────────────┐    │
│  │  Annual — $39.99/year       │ ←  │  (highlighted)
│  │  That's $3.33/month         │    │
│  └─────────────────────────────┘    │
│  ┌─────────────────────────────┐    │
│  │  Monthly — $4.99/month      │    │
│  └─────────────────────────────┘    │
│                                     │
│  [Start 7-day free trial]           │
│                                     │
│  Restore purchases · Terms          │
└─────────────────────────────────────┘
```

### A/B Tests (via RevenueCat)

| Test | Variants | Metric |
|------|----------|--------|
| Trial length | 3-day vs 7-day | Conversion rate |
| Price point | $3.99 vs $4.99 vs $5.99 monthly | Revenue per user |
| Annual discount | 30% vs 40% vs 50% off | Annual adoption rate |
| Paywall timing | After 2nd vs 3rd vs 5th cycle | Conversion + retention |
| Social proof | With/without "10,000+ users" badge | Conversion rate |

---

## 5. Revenue Diversification (Future)

### Beyond Subscriptions

| Revenue Stream | Timeline | Potential |
|---------------|----------|-----------|
| **Team/Enterprise tier** | Month 8+ | $7.99/user/mo, higher LTV |
| **Affiliate partnerships** | Month 6+ | Water bottles, desk accessories (5-10% commission) |
| **White-label/API** | Year 2+ | License the ritual engine to corporate wellness platforms |
| **Premium AI features** | Month 12+ | Advanced coaching, personalized ritual design |
| **Data insights (anonymized)** | Year 2+ | Aggregate productivity research (opt-in only) |

### What We Will NOT Do

- ❌ Ads in the free tier (destroys the calm brand)
- ❌ Sell user data (trust is the product)
- ❌ Lifetime purchase option (unsustainable for ongoing AI/server costs)
- ❌ In-app purchases for cosmetics (not a game)

---

## 6. Pricing Psychology

### Anchoring

- Show annual price first (anchors to lower monthly equivalent)
- Display "Save 33%" badge on annual plan
- Show daily cost: "$0.11/day for sustainable productivity"

### Loss Aversion

- After trial: "Your 14 journal entries and weekly insights will be locked"
- Streak at risk: "Keep your 21-day streak alive with Pro"

### Social Proof

- "Join 10,000+ professionals in rhythm" (after reaching that milestone)
- App Store rating badge on paywall
- Testimonial quotes from beta testers

### Friction Reduction

- Apple Pay / Face ID for instant purchase
- No account required for free tier
- Restore purchases prominent (App Store requirement + trust signal)

---

## 7. Churn Prevention

| Signal | Intervention |
|--------|-------------|
| No cycles in 3 days | Push: "Missing your rhythm? Even one cycle helps." |
| Skipping rituals consistently | In-app: "Want to shorten your ritual to 2 minutes?" |
| Approaching renewal | Email: "Your year in rhythm" (stats, highlights) |
| Cancel intent | Offer: pause subscription for 1 month (retain vs lose) |
| Post-cancel | Email after 30 days: "We've added [new feature]. Come back?" |

### Retention Hooks

1. **Journal history** — Months of micro-entries become valuable. Leaving = losing memories.
2. **AI insights** — Patterns only visible over time. "You're 40% more productive on Tuesdays."
3. **Streak** — Gentle (not punitive), but present. "42 days in rhythm."
4. **Calendar integration** — Once set up, switching apps means reconfiguring everything.
5. **Watch habit** — Haptic rituals become muscle memory.
