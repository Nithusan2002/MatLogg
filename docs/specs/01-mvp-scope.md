# MatLogg iOS – Spesifikasjon

## Gjeldende lanseringsscope – 3. oktober 2026

Første lansering lagrer domenedata bare på enheten: matlogger, vann, mål,
vekt, favoritter, egne produkter, lagrede måltider og bilder. Ingen skybackup,
kontobasert gjenoppretting eller flerenhetssynk tilbys. Valgfri Supabase Auth
og brukerinitierte eksterne katalog-/bildeoppslag beholdes.

`DomainUploadPolicy.localOnly` er eksplisitt ved app-roten og standard i alle
SyncEngine-initializers. Releasebygg har ingen policy som åpner opplasting.
Et backendflagg alene kan derfor ikke sende historikken. Køen beholdes atomisk
med domenedata, uten opplasting eller retry-timere. Kontokobling gir ikke
opplastingsgodkjenning. Framtidig skyfunksjon krever eget brukervalg,
historikkvalg, serverautorisasjon og nødvendige rettsgrunnlag før aktivering.

Status er «Lagret på denne enheten». Eksport er en JSON-kopi for innsyn/deling;
appen kan ikke importere den. iCloud-/Finder-restore er ikke demonstrert.
Data kan gå tapt ved avinstallering eller tap av telefonen.

## 1. MVP-Scope & Suksessmetrikker

### MVP-Fase: "Core Logging"

**Tidslinje:** 12 uker  
**Platform:** iOS 17.0+
**Team:** 1 iOS-engineer, 1 backend-engineer, 1 designer

---

## 1.1 MVP-Features (In-Scope)

| Feature | Prioritet | Beskrivelse |
|---------|-----------|-------------|
| **Valgfri konto** | P0 | Full lokal bruk uten konto. Apple eller e-post/passord for konto; Google er senere scope. |
| **Onboarding** | P0 | Direkte første logging med automatisk lokal profil. Konto og mål er valgfrie; mål settes under Profil. |
| **Home-skjermen** | P0 | Status (totalt kcal/makro vs mål), måltidsrad (Frokost/Lunsj/Middag/Snack), kontekstuell legg-til per måltid og logging-liste. Generisk søk/skann åpnes fra den vedvarende Loggfør-handlingen. |
| **Strekkode-skanning** | P0 | EAN- eller GS1 Data Matrix-skann → GTIN-oppslag → produktkort → logging |
| **Produktkort** | P0 | Næring per 100g, standard porsjonsstørrelser med antall og historisk grunnlag, mengdevelger (prefill: 100g), "Legg til"-knapp |
| **Logging-operasjon** | P0 | Lagre eksakt mengde til valgt måltid og valgt dato, inkludert fremtidig dato |
| **Kompakt loggbekreftelse** | P0 | Etter logging: vare, mengde og måltid + «Angre», uten å blokkere videre logging |
| **Skann-historikk** | P0 | Panel med nylig skannede varer; tapp åpner produktkort (100g prefill igjen) |
| **Favoritter** | P0 | Toggle fra produktkort, tilgjengelig i Søk og hurtigvalg på Home |
| **Loggfør igjen i hurtigmenyen** | P1 | Loggfør-menyen har en eksplisitt knapp med siste registrerte mengde/enhet til valgt dato og måltid. Lokal lagring med Angre; uforenlig mengde-/porsjonsgrunnlag åpner produktkortet. |
| **Måltidsgjenbruk** | P1 | Gårsdagens enkeltmåltid på Hjem: forhåndsvisning, justering og angre. Se [avgrensning](../meal-reuse.md). |
| **Lagrede måltider** | P1 | Lagre et registrert enkeltmåltid som navngitt mal med valgfritt lokalt bilde, justere og loggføre atomisk. Se [avgrensning](../saved-meals.md). |
| **Ikke funnet-flow** | P0 | Minimum input (navn + kcal/protein/karb/fett per 100g), "Fullfør senere", lagres lokalt som unverified |
| **Innstillinger** | P1 | Haptics/lyd toggle, sikkerlogging-ut, slette data, om |
| **Del produkt (beta)** | P1 | Engangslink fra produktkort, web-preview med åpne-knapp, import som kopi |
| **Offline-funksjonalitet** | P0 | Lokal SQLite DB og hvilende event-kø; ingen opplasting |

---

## 1.2 Out-of-Scope MVP

- [ ] Gruppering / venner / social features
- [ ] Detaljert barcode-database-hosting (strekkoder fra Open Food Facts; Matvaretabellen er lokal råvarekatalog)
- [ ] Web-app (bare web-deling og fallback)
- [ ] Kalender-view, uke-sammeligning, statistikk-grafer
- [ ] Oppskrifter / målkjemning
- [ ] Apple Watch, widgets
- [ ] Multi-language (kun norsk + engelsk i MVP)
- [ ] Push-notifikasjoner
- [ ] Macros-planlegging (meal prep); enkel forhåndsregistrering på en valgt fremtidig dato inngår i vanlig logging
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
- **Offline-funksjonalitet:** lokal logging uten nett; ingen opplasting når nett kommer tilbake
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
Åpne app → Søk/skann/manuell registrering → Kontroller mengde og måltid → Lagre lokalt → Hjem med Angre
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
- ✅ Haptics/lyd-feedback virker på iOS 17+

## Tillegg 2026-09-30: vannlogging

Hjem tilbyr ett trykk per glass, daglig antall, angre og fjerning av ett glass.
Registrering følger valgt dato og lagres lokalt med atomisk synkhendelse. Ingen
antatt glassvolum, drikkemål, påminnelser eller helseintegrasjon.

## Morgensjekk utsatt (2026-10-03)

Daglig innsjekk er tatt ut av Hjem inntil videre for å prioritere matlogging.
Valgfri vektregistrering og vekthistorikk beholdes under Oversikt.
Se `../design-and-user-flow.md` for gjeldende flyt.

### Manuelle produkter: næringsgrunnlag (2026-10-03)

Manuell registrering støtter 100 g, 100 ml og porsjon/stykk med navn og kjent
størrelse i g/ml. Egne porsjoner er avgrenset til produktet som opprettes;
editor for eksisterende katalogprodukter og porsjoner uten størrelse er utenfor scope.
