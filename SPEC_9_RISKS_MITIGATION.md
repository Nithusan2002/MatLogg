# MatLogg – Risikoer & Mitigering

## 9.1 Tekniske Risikoer

### **Risk T-1: Barcode Database Unavailable/Unreliable**

| Alvorlighetsgrad | Sannsynlighet | Impact |
|------------------|---------------|--------|
| **HØYT** | 60% | App-breaking (can't scan) |

**Scenario:**
```
API til Matvaretabellen eller tredjepartsbarcode-leverandør er nede
Bruker kan ikke scanne eller få produktinfo
```

**Mitigering:**
1. **Seed local DB** med ~500 mest brukte produkter (offline fallback)
2. **Cache**: Alle skanninger caches lokalt (never re-fetch samme EAN)
3. **Multiple providers**: 
   - Primary: Matvaretabellen
   - Fallback: Open Food Facts API (Global)
4. **Graceful degradation**: "Søk manuelt" fallback hvis API nede
5. **Retry logic**: Exponential backoff + circuit breaker
6. **Monitoring**: Alert if >5% barcode lookup failures

**Acceptance Criteria:**
- Offline: >80% of common products available
- Online: 95% barcode lookup success rate
- Fallback UX: <30s to "Søk manuelt" option

---

### **Risk T-2: Sync Loss / Data Corruption**

| Alvorlighetsgrad | Sannsynlighet | Impact |
|------------------|---------------|--------|
| **KRITISK** | 5% | Complete data loss |

**Scenario:**
```
Database corruption during sync
User loses all logging history
Event-kø corrupted, can't recover sync state
```

**Mitigering:**
1. **Local DB backup**:
   - SQLite write-ahead logging (WAL mode) enabled
   - Daily backup to iOS keychain/secure enclave
   - iCloud backup integration (optional)
2. **Event log durability**:
   - All writes immediately persisted (not in-memory)
   - Sync events: marked complete only after backend ACK
3. **Data validation**:
   - Checksum on sync payloads
   - Integrity checks on load
4. **Recovery procedure**:
   - Detect corruption on app launch
   - Restore from latest backup (manual)
   - Alert user with recovery options
5. **Monitoring**:
   - Backend: validate incoming data integrity
   - Client: periodic hash-check of local DB

**Acceptance Criteria:**
- Zero unplanned data loss (monitored over 6 months)
- Corruption detected <1% of app launches
- Recovery possible 100% of time

---

### **Risk T-3: Network Latency / Unreliable Connectivity**

| Alvorlighetsgrad | Sannsynlighet | Impact |
|------------------|---------------|--------|
| **HØYT** | 70% | Poor UX, abandoned logs |

**Scenario:**
```
User on slow 3G (latency 2-3s)
Barcode scan takes 5+ seconds
User frustrated, closes app
```

**Mitigering:**
1. **Local-first**: Always write locally first (instant feedback)
2. **Optimistic UI**:
   - Show mini-receipt immediately (before sync)
   - Mark as "pending sync" if network slow
3. **Timeout handling**:
   - Default timeout: 5s for barcode lookup
   - User option: [Prøv igjen] or [Søk manuelt]
4. **Prefetch**:
   - Cache recent 50 scan products on first load
   - Use Reachability API to detect connection type
5. **Progressive enhancement**:
   - Offline: works fully (local DB)
   - Slow: works with delays (visual feedback)
   - Online: instant (no changes to UX)

**Acceptance Criteria:**
- Offline logging: 100% functional
- Slow network (>3s latency): still usable (timeout + fallback)
- Online barcode scan: <1.5s avg

---

### **Risk T-4: iOS App Rejection / AppStore Review Delays**

| Alvorlighetsgrad | Sannsynlighet | Impact |
|------------------|---------------|--------|
| **MEDIUM** | 40% | 1-2 week launch delay |

**Scenario:**
```
App rejected for privacy/nutrition misrepresentation
Resubmit cycle: 1 week each
Delayed launch → competitors gain foothold
```

**Mitigering:**
1. **Review preparation**:
   - Privacy policy drafted (GDPR compliant)
   - App health claims: removed/minimized (no medical claims)
   - Barcode scanning: explained as reference only
   - Screenshots: reviewed by legal
2. **Early submission**:
   - Submit to TestFlight 2 weeks before target launch
   - Allow review cycle 1: catch issues early
   - Resubmit optimized version
3. **Support contact**:
   - AppStore support contact ready
   - Response plan if rejected
4. **Backup: Public Beta**:
   - TestFlight link shared publicly (backup distribution)
   - Build momentum during AppStore review wait

**Acceptance Criteria:**
- First submission acceptance rate: >80%
- Resubmit turnaround: <1 week
- Launch delay impact: <2 weeks

---

### **Risk T-5: Backend Performance Under Load**

| Alvorlighetsgrad | Sannsynlighet | Impact |
|------------------|---------------|--------|
| **MEDIUM** | 30% | App crashes / slow sync |

**Scenario:**
```
5,000 users try to sync simultaneously (morning peak)
Backend overloaded, sync fails for 20%
Users see "Sync error" repeatedly
```

**Mitigering:**
1. **Backend scaling**:
   - Auto-scaling on AWS/GCP (CloudRun, Lambda)
   - Database read replicas (for barcode lookups)
   - Redis caching layer (popular products)
2. **Rate limiting**:
   - Per-user: 60 syncs/hour (prevents abuse)
   - Exponential backoff on client (1s, 2s, 4s, 8s)
3. **Load testing**:
   - Simulate 10k concurrent users (k6, JMeter)
   - Target: 99th percentile <2s response time
   - Identify bottlenecks pre-launch
4. **Monitoring**:
   - Datadog / New Relic: track latency, errors, throughput
   - Alerts: if p99 latency >3s
5. **Graceful degradation**:
   - Non-critical endpoints timeout first
   - Barcode lookup: cached result or 404
   - Sync: retry queue prioritized

**Acceptance Criteria:**
- Handle 10k concurrent syncs
- p50 response: <500ms
- p99 response: <2s
- Error rate: <1%

---

## 9.2 Product / Business Risks

### **Risk P-1: Low User Engagement / High Churn**

| Alvorlighetsgrad | Sannsynlighet | Impact |
|------------------|---------------|--------|
| **HØYT** | 50% | MVP fails (shut down) |

**Scenario:**
```
App launch: 1,000 signups
Day-7 retention: 25% (target 40%)
Users don't return after initial logging
```

**Mitigering:**
1. **Early feedback loops**:
   - Beta testers: conduct 10+ interviews
   - Identify friction points (empty-state, onboarding, scanning speed)
   - Iterate based on feedback
2. **Engagement features**:
   - Mini-achievements ("7 days logged!")
   - Haptics/lyd: positive reinforcement
   - Streak tracking (future)
3. **Onboarding optimization**:
   - Test 3 variants of onboarding flow
   - Measure: completion rate, time-to-first-log
   - A/B test in v1 (if cohort available)
4. **Content strategy**:
   - Blog: "Logging hacks", nutrition tips
   - Share: success stories from beta
5. **Community building**:
   - Beta tester Discord/Slack
   - Monthly challenge (v1+)

**Acceptance Criteria**:
- Day-1 retention: >60%
- Day-7 retention: >40%
- Day-30 retention: >25%
- Time-to-first-log: <10 min avg

---

### **Risk P-2: Barcode Inaccuracy / Trust Issues**

| Alvorlighetsgrad | Sannsynlighet | Impact |
|------------------|---------------|--------|
| **HØYT** | 40% | Users lose trust, abandon |

**Scenario:**
```
User scans bread product
Database lists: 240 kcal per 100g (actually 200 kcal)
User logs 300g → thinks ate 720 kcal (actually 600)
Discovers error after 2 weeks
```

**Mitigering:**
1. **Data quality**:
   - Use verified data source (Matvaretabellen)
   - Only seed with high-confidence products (MVP)
   - Flag unverified products: "Bruker-opprettet, ikke verifisert"
2. **User education**:
   - Onboarding: "Nutritional data is reference only"
   - UI disclaimer: "Data source: Matvaretabellen"
   - Settings: link to data sources
3. **Correction mechanism**:
   - Report feature: flag incorrect nutrition
   - Moderation: review flags, update product
4. **Transparency**:
   - Product detail screen: shows source + last updated
   - User can see who created/verified

**Acceptance Criteria**:
- >95% of MVP products from verified source
- Error report mechanism live (v1)
- Moderation SLA: 24h response time

---

### **Risk P-3: Competitive Entry / Market Saturation**

| Alvorlighetsgrad | Sannsynlighet | Impact |
|------------------|---------------|--------|
| **MEDIUM** | 60% | Market share loss |

**Scenario:**
```
MyFitnessPal, Cronometer, Lose It! expand to Norway
Larger budgets, more features, more users
MatLogg loses new user acquisition
```

**Mitigering:**
1. **Differentiation**:
   - Focus: Norwegian language + local data
   - UX: scanning experience (ultra-fast, haptics)
   - Community: local food culture, recipes
2. **Speed-to-market**:
   - MVP launch within 12 weeks (first-mover advantage in Norway)
   - Fast iteration (v1 in 2 months)
3. **Network effects**:
   - Social features (v2): lock-in via friends
   - Referral program: incentivize growth
4. **Defensibility**:
   - Build data moat: community-generated products
   - Brand: "The Norwegian way to track nutrition"

**Acceptance Criteria**:
- 3-month head start before major competitor enters
- Brand recognition: >30% awareness in target segment (v1)

---

### **Risk P-4: Regulatory / Privacy Compliance Issues**

| Alvorlighetsgrad | Sannsynlighet | Impact |
|------------------|---------------|--------|
| **MEDIUM** | 20% | Legal issues, forced shut-down |

**Scenario:**
```
Norwegian DPA (Datatilsynet) audits app
Privacy policy incomplete
GDPR violations found
```

**Mitigering:**
1. **Legal preparation** (before launch):
   - Privacy policy: reviewed by legal (Norwegian/EU law)
   - Terms of Service: GDPR-compliant deletion clause
   - Data processing agreement: prepared
2. **Data hygiene**:
   - Minimal data collection (name, email, logs only)
   - No third-party tracking (no Google Analytics)
   - User deletion: supported (30-day retention before purge)
3. **Security**:
   - Encryption in transit (TLS 1.2+)
   - Encryption at rest (CoreData + Keychain)
   - No unencrypted logs sent to backend
4. **Documentation**:
   - Data retention policy (1 year default)
   - Audit trail for data access
   - Incident response plan

**Acceptance Criteria**:
- Legal review: passed before launch
- Privacy policy: GDPR-compliant
- Data deletion: functional, tested

---

## 9.3 Operational Risks

### **Risk O-1: Key Person Dependency**

| Alvorlighetsgrad | Sannsynlighet | Impact |
|------------------|---------------|--------|
| **MEDIUM** | 40% | Project delays |

**Scenario:**
```
iOS developer gets sick / leaves project
No other team member knows codebase
Project stalled 2 weeks
```

**Mitigering:**
1. **Documentation**:
   - Architecture guide (Wiki)
   - Code comments (complex logic)
   - Runbook for deployment
2. **Knowledge sharing**:
   - Pair programming: 1 day/week
   - Code reviews: mandatory (all commits)
   - Design doc: for major features
3. **Backup resources**:
   - Contract with freelance iOS dev (on standby)
   - Backend dev can help (partial capability)
4. **Process**:
   - All knowledge in Jira/Confluence
   - No Slack-only decisions (logged)

**Acceptance Criteria**:
- 1-week knowledge transfer plan (in case of departure)
- >80% code documented

---

### **Risk O-2: Scope Creep**

| Alvorlighetsgrad | Sannsynlighet | Impact |
|------------------|---------------|--------|
| **HØYT** | 80% | Launch delay |

**Scenario:**
```
Product owner adds new feature: "AI meal recognition"
Estimated 4 weeks, but actually 8 weeks
MVP launch delayed 1 month
```

**Mitigering:**
1. **Frozen MVP scope**:
   - Sign-off: CEO + product lead approve final scope
   - No additions after week 2 (code-freeze approach)
   - All new ideas → v1 backlog
2. **Prioritization framework**:
   - MoSCoW (Must/Should/Could/Won't)
   - Clear criteria for what's MVP vs v1
3. **Tracking**:
   - Weekly scope review (is any creep happening?)
   - Burndown chart: track against MVP baseline
4. **Communication**:
   - All stakeholders aware: MVP is minimal, v1 is growth

**Acceptance Criteria**:
- MVP scope document signed-off (all stakeholders)
- 100% of P0 features shipped (no cuts)
- 0 unplanned features added post-week-2

---

### **Risk O-3: Testing / QA Gaps**

| Alvorlighetsgrad | Sannsynlighet | Impact |
|------------------|---------------|--------|
| **MEDIUM** | 50% | Critical bugs discovered post-launch |

**Scenario:**
```
Sync failure on specific iOS version
Discovered by user after launch
Takes 1 week to fix, deploy patch
```

**Mitigering**:
1. **Test coverage**:
   - Unit tests: core logic (>60% target for MVP)
   - Integration tests: barcode → logging flow
   - E2E tests: critical user journeys (TestFlight)
2. **Device testing**:
   - Min: iPhone 11, 12, 13, 14 (4 devices)
   - iOS versions: 14, 15, 16, 17 (latest 4)
   - Test on WiFi, 4G, 3G, offline
3. **Beta testing**:
   - TestFlight: 500+ testers, 2 weeks minimum
   - Feedback channels: in-app bug report + survey
   - Monitoring: crash rates, error logs (Sentry)
4. **Regression testing**:
   - Before each release: manual checklist
   - Critical flows: tested on all devices

**Acceptance Criteria**:
- Crash rate: <0.5% in TestFlight
- Critical bugs: <5 before launch
- Test coverage: >60% core logic

---

## 9.4 Risk Mitigation Tracking

### **Risk Matrix (Probability × Impact)**

```
        Low Impact          Medium Impact       High Impact
        (1)                 (2)                 (3)
High P  [P-3 MEDIUM]        [T-1 HØYT]          [P-1 HØYT]
(60-80%)                                        [T-2 KRITISK]
                                               [T-3 HØYT]
                                               [O-2 HØYT]

Med P   [T-5 MEDIUM]        [T-4 MEDIUM]        [P-2 HØYT]
(30-50%)                    [P-4 MEDIUM]        [O-1 MEDIUM]
                            [O-3 MEDIUM]

Low P   [T-2 KRITISK]*      [P-4 MEDIUM]        [P-3 MEDIUM]
(5-20%) *rare but severe    [O-1 MEDIUM]
```

### **Mitigation Owners**

| Risk | Owner | Mitigations | Status |
|------|-------|------------|--------|
| T-1 (Barcode DB) | Backend lead | Seed DB, cache, fallback | IN PROGRESS |
| T-2 (Data loss) | iOS lead | Backup, WAL, validation | IN PROGRESS |
| T-3 (Latency) | Full team | Local-first, optimize, timeouts | PLANNED |
| T-4 (AppStore rejection) | Product | Legal review, screenshots | PLANNED |
| T-5 (Backend load) | Backend | Auto-scaling, rate limiting | PLANNED |
| P-1 (Low engagement) | Product | Beta feedback, features | PLANNED |
| P-2 (Barcode accuracy) | Product | Data source, moderation | PLANNED |
| P-3 (Competition) | Product | Differentiation, speed | ONGOING |
| P-4 (Compliance) | Product + Legal | Privacy policy, GDPR | IN PROGRESS |
| O-1 (Key person) | Manager | Documentation, backup | PLANNED |
| O-2 (Scope creep) | PM | Frozen scope, sign-off | IN PROGRESS |
| O-3 (QA gaps) | QA lead | Test coverage, TestFlight | PLANNED |

---

## 9.5 Contingency Plans

### **If Barcode DB Unavailable (T-1)**

**Plan B:**
```
1. Use local seeded DB (500 products)
2. Enable manual product search + creation
3. Communicate: "Limited scanning availability, manual search recommended"
4. Timeline: restore service within 24h
5. Fallback: if >24h, use backup provider (Open Food Facts)
```

---

### **If Data Loss Occurs (T-2)**

**Plan B:**
```
1. Restore from daily backup (iCloud or local)
2. Notify affected users (email + in-app)
3. Offer compensation: "Premium features free for 1 month"
4. Root cause analysis: internal report
5. Implement stronger safeguards
```

---

### **If AppStore Rejection (T-4)**

**Plan B:**
```
1. Analyze rejection reason (privacy, health claims, etc)
2. Resubmit within 5 days (expedited review)
3. Temporary: TestFlight public link as distribution
4. Timeline: launch via AppStore within 2 weeks
```

---

### **If Backend Overloaded (T-5)**

**Plan B:**
```
1. Enable rate limiting (30 req/min per user)
2. Show maintenance banner: "Sync service temporarily slow"
3. Scale backend (auto-scaling triggers)
4. Degrade non-critical services (leaderboard queries first)
5. Restore within 4h
```

---

## 9.6 Risk Review Cadence

```
Weekly (During MVP):
• T-1, T-3 (network issues): daily monitoring
• O-2 (scope creep): burndown review

Monthly:
• All technical risks: status update
• Test coverage, deployment success rate
• User feedback (churn, crashes)

Quarterly (Post-Launch):
• Full risk re-assessment
• New risks identified (market, product)
• Update mitigation strategies
```

