# MatLogg – Roadmap: MVP → v1 → v2

## 8.1 Release Timeline

```
┌──────────────────────────────────────────────────────────────┐
│ MVP (v0.1–0.9)      v1.0 (Stable)    v2.0 (Growth)         │
│ ├─ 12 weeks          ├─ 8 weeks       ├─ 12+ weeks         │
│ └─ Jan–Mar 2025      └─ May–Jun       └─ Jul–Dec 2025      │
└──────────────────────────────────────────────────────────────┘
```

---

## 8.2 MVP Phase (0.1–0.9): Core Logging

**Timeline:** 12 uker (Jan–Mar 2025)

### **Milestones**

| Week | Phase | Deliverable |
|------|-------|-------------|
| 1–2 | Architecture | Backend setup, auth, DB, iOS init |
| 3–4 | Core UI | Home, logging, produktkort |
| 5–6 | Scanning | Barcode scanning + produktoppslag |
| 7–8 | Offline | SQLite sync, event-kø |
| 9–10 | Refinement | Bug fixing, UX polish |
| 11–12 | Testing | TestFlight beta, AppStore submission |

### **MVP Features (Frozen)**

✅ Auth (Apple/Google/Email)  
✅ Onboarding (mål, kalorier, makroer)  
✅ Home: status + logg-liste + måltidsrad  
✅ Strekkode-skanning  
✅ Produktkort (100g prefill)  
✅ Logging + mini-kvittering  
✅ Skann-historikk  
✅ Favoritter (local toggle)  
✅ "Ikke funnet" + product creation (min)  
✅ Innstillinger (haptics/lyd toggle)  
✅ Offline-first + synk  
✅ Del produkt (link MVP)  

### **MVP Out of Scope**

❌ Social features (friends, groups)  
❌ Analytics / graphs / trends  
❌ Macro nutrient detailed breakdowns  
❌ Recipes / meal plans  
❌ Web app  
❌ Multi-language (MVP: Norsk + English UI)  
❌ Apple Health integration  
❌ Widgets / Apple Watch  
❌ Push notifications  
❌ Premium features / paywall  

### **Success Criteria at Launch**

- ✅ >50 Norwegian products seeded (Matvaretabellen subset)
- ✅ 100% P0 features functional
- ✅ <0.5% crash rate in TestFlight (>500 testers)
- ✅ App load time <2s, scan-to-productcard <3s
- ✅ Offline logging works without internet
- ✅ No data loss during sync
- ✅ Haptics/sound working on iOS 14+

---

## 8.3 v1.0 Phase: Stability & Polish

**Timeline:** 8 uker (May–Jun 2025)  
**Target:** App Store public release

### **v1.0 Goals**

- Stabilize MVP
- Fix bugs from beta testing
- Optimize performance
- Improve onboarding UX
- Expand product database (500+ seeded products)
- Moderation system live

### **v1.0 New Features**

| Feature | Priority | Effort | Notes |
|---------|----------|--------|-------|
| **Product moderation dashboard** | P0 | M | Admins review unverified products |
| **Improved search** | P1 | M | Better relevance, autocomplete |
| **Weekly summary** | P1 | S | "This week: X kcal avg" |
| **Goal history tracking** | P1 | M | See past goals, change dates |
| **Export data (CSV)** | P1 | S | User data export for GDPR |
| **Barcode database sync** | P1 | L | Auto-update Matvaretabellen monthly |
| **Multi-language UI** | P2 | M | Add English, possibly Swedish |
| **Dark mode support** | P2 | S | iOS system dark mode |
| **Meal templates** | P2 | L | "Quick add" common breakfasts |
| **Undo/redo** | P2 | S | Limited undo for last 5 actions |

### **v1.0 Removed Features**

- Beta tag (now "production" release)
- Experimental features (if any)

### **v1.0 Success Criteria**

- ✅ Day-7 retention >40%
- ✅ DAU >500
- ✅ Avg 4+ logs/user/day (among active)
- ✅ <0.2% crash rate
- ✅ App Store featured (potential)

---

## 8.4 v2.0 Phase: Growth & Social

**Timeline:** 12+ uker (Jul–Dec 2025)

### **v2.0 Vision**

MatLogg becomes not just a logging tool, but a **community platform** for food tracking and healthy eating.

### **v2.0 Major Features**

| Feature | Priority | Effort | Rationale |
|---------|----------|--------|-----------|
| **Friends / Social** | P0 | L | Share goals, compete, motivate |
| **Leaderboards** | P0 | M | Weekly/monthly challenges |
| **Public food DB** | P0 | L | Community-contributed products |
| **Recipe builder** | P1 | L | Create meals from ingredients |
| **Meal planning** | P1 | L | Plan next week, auto-log |
| **Progress graphs** | P1 | M | Trend lines, 7/30-day views |
| **Apple Health sync** | P2 | L | Read/write health data |
| **Notifications** | P2 | M | Goal reminders, achievements |
| **Web app** | P2 | XL | Full feature parity on web |
| **Android port** | P2 | XL | 100% feature parity |

### **v2.0 Technical Debt**

- [ ] Migrate to SwiftUI (if still using UIKit in MVP/v1)
- [ ] Implement push notifications (APNs)
- [ ] Add analytics suite (Amplitude, Mixpanel)
- [ ] Security audit + penetration testing
- [ ] Performance profiling (battery, data, memory)
- [ ] A/B testing framework

### **v2.0 Success Criteria**

- ✅ DAU >5,000
- ✅ Day-30 retention >30%
- ✅ User generated content: 40%+ of products from community
- ✅ Social referrals: 20%+ of new signups from existing users
- ✅ Revenue (if implemented): $XXX MRR

---

## 8.5 Prioritization Matrix (MoSCoW for MVP→v1)

### **MVP: Must Have**

```
┌─────────────────────────────────────────┐
│ MUST HAVE (MVP Launch)                  │
├─────────────────────────────────────────┤
│ ✓ Auth                                   │
│ ✓ Onboarding                             │
│ ✓ Home + logging                         │
│ ✓ Barcode scanning                       │
│ ✓ Offline-first + sync                   │
│ ✓ Haptics/lyd (toggles)                  │
│ ✓ Settings                               │
└─────────────────────────────────────────┘
```

### **v1: Should Have**

```
┌─────────────────────────────────────────┐
│ SHOULD HAVE (v1 Stabilization)          │
├─────────────────────────────────────────┤
│ □ Moderation dashboard (backend)         │
│ □ Weekly summary view                    │
│ □ Better search / autocomplete           │
│ □ Export data                            │
│ □ Dark mode                              │
│ □ Multi-language UI                      │
└─────────────────────────────────────────┘
```

### **v2: Could Have**

```
┌─────────────────────────────────────────┐
│ COULD HAVE (v2 Growth)                  │
├─────────────────────────────────────────┤
│ □ Social features                        │
│ □ Leaderboards                           │
│ □ Recipe builder                         │
│ □ Meal planning                          │
│ □ Apple Health                           │
│ □ Notifications                          │
│ □ Web app                                │
│ □ Android                                │
└─────────────────────────────────────────┘
```

### **Post-v2: Won't Have (Out of Scope)**

```
┌─────────────────────────────────────────┐
│ WON'T HAVE (Out of Scope Indefinitely)   │
├─────────────────────────────────────────┤
│ ✗ Wearable integration (fitness bands)   │
│ ✗ Voice logging ("log egg and toast")    │
│ ✗ AI meal recognition (photo scan)       │
│ ✗ Medication tracking                    │
│ ✗ Nutrient database completeness         │
│ ✗ White-label licensing                  │
│ ✗ Enterprise SSO (Okta, AD)              │
└─────────────────────────────────────────┘
```

---

## 8.6 Dependency Map

```
MVP Core
├─ Auth
│  └─ Onboarding
│     └─ Home
│        ├─ Logging
│        │  └─ Productkort
│        │     ├─ Barcode lookup
│        │     ├─ "Ikke funnet"
│        │     └─ Mini-kvittering
│        └─ Settings
│           ├─ Haptics/lyd toggle
│           └─ Data management
│
└─ Offline
   ├─ SQLite DB
   ├─ Event-kø
   └─ Sync engine
      └─ Backend API
         ├─ Auth endpoints
         ├─ Product DB
         ├─ Logging endpoints
         └─ Sync handler

v1 Enhancements
├─ Moderation system (requires: product DB maturity)
├─ Search improvements (requires: indexed DB)
└─ Analytics (requires: stable logging)

v2 Growth
├─ Social (requires: user profiles, auth maturity)
├─ Health sync (requires: iOS HealthKit integration)
└─ Web app (requires: API stability, CORS)
```

---

## 8.7 Resource Allocation

### **MVP Phase**

```
iOS Development:    60% (1.2 FTE)
Backend:            30% (0.6 FTE)
Design/UX:          10% (0.2 FTE)
─────────────────────────────
Total:              2 FTE
Duration:           12 weeks
```

### **v1 Phase**

```
iOS Development:    40% (0.4 FTE)
Backend:            30% (0.3 FTE)
Product:            15% (0.15 FTE)
Moderation/QA:      15% (0.15 FTE)
─────────────────────────────
Total:              1 FTE
Duration:           8 weeks
```

### **v2 Phase**

```
iOS Development:    35%
Backend:            35%
Product:            15%
DevOps/Infra:       10%
Moderation:         5%
─────────────────────────────
Total:              3 FTE (expanded)
Duration:           12+ weeks
```

---

## 8.8 Marketing & Go-to-Market

### **MVP Launch**

- Soft launch: TestFlight beta (~500 testers)
- Community feedback gathering (survey, interviews)
- Product Hunt prep (if timing aligns)
- Press kit ready (screenshots, demo video)

### **v1 Launch (App Store)**

- App Store listing optimized
- Launch press release
- Social media campaign (Twitter, Instagram)
- Influencer outreach (health/nutrition community)

### **v2 Milestones**

- Feature announcements blog posts
- Social referral campaign ("Invite 3 friends")
- Case studies: user testimonials
- Possible affiliate program

---

## 8.9 Technical Debt Management

### **MVP: Accept Debt**

```
✓ Quick wins prioritized
✓ Shortcuts on code quality acceptable
✓ Manual testing focus
✓ Tech debt logged for v1
```

### **v1: Repay 20% Debt**

```
□ Code refactoring
□ Unit test coverage (target: 60%)
□ Architecture documentation
□ Performance profiling
```

### **v2: Repay 50% Debt**

```
□ End-to-end testing
□ Load testing (backend)
□ Security hardening
□ Dependency updates
```

---

## 8.10 Success Metrics by Phase

### **MVP**

```
Launch Readiness:
• 100% P0 features complete
• <0.5% crash rate
• App load <2s

Adoption (First month):
• Signups: >1,000
• Day-1 retention: >60%
• Day-7 retention: >40%
```

### **v1**

```
Platform Maturity:
• DAU: >500
• Logs/user/day: 4+
• Crash rate: <0.2%

Product Quality:
• Feature parity across devices
• Offline sync 100% reliable
• Support tickets <10/week
```

### **v2**

```
Growth:
• DAU: >5,000
• Day-30 retention: >30%
• Social signups: >20%

Sustainability:
• MAU: >15,000
• Revenue: $XXX (if monetized)
• Content moderation <5% error rate
```

---

## 8.11 Version Branching Strategy

```
main (stable, v1.0+)
  ↑
release/v1.0 (release candidate)
  ↑
develop (integration branch for next version)
  ↑
feature/... (feature branches)
  ├─ feature/social-friends
  ├─ feature/leaderboards
  ├─ feature/meal-planning
  └─ ...
```

---

## 8.12 Sunset / Deprecation Policy

### **For MVP Features (Never Sunsetted)**

```
Core logging, auth, offline: permanent
Will be maintained indefinitely
Backward compatibility: required
```

### **For Experimental Features (v1+)**

```
If feature has <5% adoption after 3 months: consider sunsetting
Timeline: 6-week deprecation notice
Notification: in-app banner + email
```

### **For Old API Versions (v2+)**

```
/v1 endpoints: maintained 1 year after /v2 launch
Then: 3-month deprecation warning
Finally: 410 Gone (archived)
```

