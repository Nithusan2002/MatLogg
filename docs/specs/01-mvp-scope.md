# MatLogg iOS – Spesifikasjon

## 1. MVP-Scope & Suksessmetrikker

### MVP-Fase: "Core Logging"

**Tidslinje:** 12 uker  
**Platform:** iOS 14.0+  
**Team:** 1 iOS-engineer, 1 backend-engineer, 1 designer

---

## 1.1 MVP-Features (In-Scope)

| Feature | Prioritet | Beskrivelse |
|---------|-----------|-------------|
| **Autentisering** | P0 | Sign in with Apple, Google, email/passord |
| **Onboarding** | P0 | Måltype (weght loss/maintain/gain), kalorimål, makromål, valgfri vektlogg |
| **Home-skjermen** | P0 | Status (totalt kcal/makro vs mål), måltidsrad (Frokost/Lunsj/Middag/Snack), stor skann-knapp, logging-liste |
| **Strekkode-skanning** | P0 | EAN-skann → produktoppslag → produktkort → logging |
| **Produktkort** | P0 | Næring per 100g, standard porsjonsstørrelser, mengdevelger (prefill: 100g), "Legg til"-knapp |
| **Logging-operasjon** | P0 | Lagre eksakt mengde til valgt måltid, datomarkering |
| **Mini-kvittering** | P0 | Etter logging: preview av loggede verdier + "Skann neste" + "Legg til igjen" + "Lukk" |
| **Skann-historikk** | P0 | Panel med nylig skannede varer; tapp åpner produktkort (100g prefill igjen) |
| **Favoritter** | P0 | Toggle fra produktkort, hurtig-liste på Home |
| **Ikke funnet-flow** | P0 | Minimum input (navn + kcal/protein/karb/fett per 100g), "Fullfør senere", lagres lokalt som unverified |
| **Innstillinger** | P1 | Haptics/lyd toggle, sikkerlogging-ut, slette data, om |
| **Del produkt (beta)** | P1 | Engangslink fra produktkort, web-preview med åpne-knapp, import som kopi |
| **Offline-funksjonalitet** | P0 | Lokal SQLite DB, event-kø, synk når nett tilbake |

---

## 1.2 Out-of-Scope MVP

- [ ] Gruppering / venner / social features
- [ ] Detaljert barcode-database-hosting (bruker Matvaretabellen + fallback)
- [ ] Web-app (bare web-deling og fallback)
- [ ] Kalender-view, uke-sammeligning, statistikk-grafer
- [ ] Oppskrifter / målkjemning
- [ ] Apple Watch, widgets
- [ ] Multi-language (kun norsk + engelsk i MVP)
- [ ] Push-notifikasjoner
- [ ] Macros-planlegging (meal prep)
- [ ] Eksport til fitnesstrackere

---

## 1.3 Suksessmetrikker (KPIer)

### Retention & Engagement
- **Day-1 Retention:** >60%
- **Day-7 Retention:** >40%
- **DAU/MAU-ratio:** >35%
- **Gjennomsnittlige logg per bruker per dag:** >4 (min 3 logginger/dag for active user)

### Teknisk Performance
- **App-start tid:** <2s (cold), <500ms (warm)
- **Skann-til-produktkort:** <1.5s (lokal cache), <3s (API-oppslag)
- **Offline-funksjonalitet:** 100% loggbar når offline; synker når nett tilbake
- **Crash-rate:** <0.5% (iOS standard)

### Brukergenerert Innhold
- **Unverified-produkter opprettet:** >20% av active users
- **Produkter delt:** >15% av active users (link-deling)

### Konvertering
- **Sign-ups → First Log:** >75%
- **First Log → Day-7 Active:** >40%

---

## 1.4 Out-of-Scope Metrikker (v1+)

- Social adoption (shares, friend invites)
- Platform-spesifikk analytics (Apple Health integration)
- Revenue (ads, premium)

---

## 1.5 MVP-Levering: Artefakter

1. **Applikasjon:**
   - iOS-app (TestFlight beta)
   - Backend-API (staging + prod)

2. **Dokumentasjon:**
   - Denne spesifikasjonen
   - API-dokumentasjon (OpenAPI/Swagger)
   - Deployment guide
   - Moderation guidelines (for unverified products)

3. **Analytics & Monitoring:**
   - Firebase Analytics (events)
   - Sentry (error tracking)
   - Custom logging (API latency, sync metrics)

---

## 1.6 Aksesspunkter til MVP

### Ny bruker:
```
Åpne app → Innlogging → Onboarding (mål) → Home → Skann/Legg til
```

### Aktiv bruker:
```
Åpne app → Home (status synlig) → Velg måltid → Skann/Legg til → Logging → Historikk
```

---

## 1.7 Fase-plan

| Uke | Fokus |
|-----|-------|
| 1–2 | Architektur, auth setup, lokal DB |
| 3–4 | Home-UI, måltidsrad, mock-logging |
| 5–6 | Strekkode-scanning + produktoppslag |
| 7–8 | Produktkort + "Ikke funnet" flow |
| 9–10 | Sync + offline |
| 11–12 | QA, bug-fixing, TestFlight-utrulling |

---

## 1.8 Success Criteria ved Launch

- ✅ 50+ norske produkter i databasen (seeded)
- ✅ 100% av P0-features fungerer
- ✅ <0.5% crash-rate i TestFlight
- ✅ All offline-funksjonalitet virker
- ✅ Haptics/lyd-feedback virker på iOS 14+
