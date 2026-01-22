# MatLogg – Brukerhistorier & Detaljerte Flyter

## 2.1 Brukerhistorier (User Stories)

### **Epic 1: Autentisering & Onboarding**

#### US-1.1: Bruker registrerer seg
```
SOM: ny bruker
ØNSKER: rask innlogging med eksisterende konto
SÅ AT: jeg slipper å opprette nytt passord

Acceptance Criteria:
□ Apple Sign in, Google Sign in, Email-passord-registrering tilgjengelig
□ Registrering krever minimum: e-post, navn, passord (hvis email)
□ Validering: e-post format, passord >8 tegn
□ Bruker sendes til onboarding etter registrering
□ Sessionstoken lagres sikkert i Keychain (iOS)
□ Ingen cookies; kun JWT-bearer-token i Authorization-header
```

#### US-1.2: Bruker setter opp mål
```
SOM: ny bruker
ØNSKER: raskt kunne angi kalorimål og makromål
SÅ AT: jeg kan begynne å logge

Acceptance Criteria:
□ Onboarding-flow: 4 skjermbilder (måltype, kalorimål, makromål, valgfri vektlogg)
□ Måltype: weight loss / maintain / gain (bestemmer baseline-anbefaling)
□ Kalorimål: input 1000–5000 kcal/dag (med default basert på måltype)
□ Makromål: % eller gram for protein/karb/fett
□ Valgfri: initiell vektlogg (today's weight)
□ Lagres til backend + lokal DB
□ "Hopp over" for vekt-logging
```

---

### **Epic 2: Logging & Oversikt (Home)**

#### US-2.1: Bruker åpner Home og ser status
```
SOM: aktiv bruker
ØNSKER: umiddelbar oversikt over hvor mye jeg har spist i dag
SÅ AT: jeg vet om jeg kan spise mer eller må passe meg

Acceptance Criteria:
□ Home viser: dato, totalt kcal (vs mål), protein/karb/fett (vs mål)
□ Status-delen: stor progress-ring (kcal %), tekst under med makro-breakdown
□ Hvis >100% kalorier: ring blir rød, "Du har overskredet målet"
□ Hvis 50–100%: ring blir oransje
□ Hvis <50%: ring blir grønn
□ Måltidsrad fast øverst: [Frokost] [Lunsj] [Middag] [Snacks] (valgt måltid highlightet)
□ Logg-liste under: dag → måltider → innslag (kronologisk)
□ Stor skann-knapp i bunnen (5 cm diameter)
□ Hvis ingen innslag i dag: "Begynn med å skanne eller legge til"
```

#### US-2.2: Bruker velger måltid før skanning
```
SOM: bruker
ØNSKER: at appen husker hvilket måltid jeg skal logge til
SÅ AT: jeg ikkje må velge det på nytt når jeg skanner

Acceptance Criteria:
□ Måltidsrad på Home-skjermen: alltid synlig, knapper for [Frokost] [Lunsj] [Middag] [Snacks]
□ Default-valg: dagens første måltid (basert på tid)
□ Valgt måltid highlightet (bakgrunnsfarve, bold tekst)
□ Tapping måltid oppdaterer "current meal"
□ "Current meal" lagres i AppState, brukes ved scan
□ Skanning åpner direkte produktkort med selected meal
□ Bruker kan endre måltid underveis i produktkort-UI
```

#### US-2.3: Bruker ser logg-liste
```
SOM: bruker
ØNSKER: å se alle ting jeg har spist i dag, organisert etter måltid
SÅ AT: jeg kan verifisere og eventuelt slette feil

Acceptance Criteria:
□ Under status: liste med struktur: [Måltid-header] → [innslag 1] [innslag 2] ...
□ Hvert innslag viser: produktnavn + mengde + kcal
□ Eksempel: "Brød (50g) → 120 kcal"
□ Fargekode måltid-headers: Frokost=blå, Lunsj=grønn, Middag=rød, Snacks=gul
□ Tapp innslag → detaljer + slett-knapp
□ Swipe for å slette (iOS standard)
```

---

### **Epic 3: Strekkode-Skanning**

#### US-3.1: Bruker skanner strekkode (happy path)
```
SOM: bruker
ØNSKER: scanne strekkode og raskt legge den til mitt måltid
SÅ AT: jeg ikkje bruker for mye tid på logging

Acceptance Criteria:
□ Tapp stor skann-knapp → åpne kamera (AVFoundation)
□ Venter på EAN-deteksjon (auto-trigger, ingen knapp)
□ Ved strekkode-deteksjon: haptic feedback (3 short taps) + lyd (pling)
□ API-oppslag: GET /api/v1/products/barcode/{ean}
□ Hvis produkt finnes:
  - Umiddelbar produktkort-visning (hoppet over loading-state)
  - Mengde-felt prefylt: 100g
  - "Legg til"-knapp satt og klar
□ Hvis ikkje funnet: "Ikke funnet"-flow (se US-3.3)
□ Maksimal latency: 3 sekunder (nett), fra skann til produktkort
□ Scannings-historikk lagres lokalt (evt. uten nett)
```

#### US-3.2: Bruker logger mengde og trykker "Legg til"
```
SOM: bruker på produktkort
ØNSKER: å endre mengde fra 100g til det jeg faktisk spiste
OG: deretter lagre det til mitt måltid

Acceptance Criteria:
□ Mengde-felt: numerisk input + stepper (+ / −) eller slider
□ Standardverdi: 100g
□ Bruker kan endre til desimal (f.eks. 145.5g)
□ "Legg til"-knapp lagrer:
  - Product ID
  - Mengde (exact value, no rounding)
  - Måltid (fra AppState)
  - Dato
  - Timestamp
□ Lokal DB-insert umiddelbar
□ Network sync enqueued (background)
□ Mini-kvittering vises: "✓ Brød (150g) → 300 kcal lagt til Lunsj"
□ Haptic feedback (double-tap) + beep
□ Next actions: [Skann neste] [Legg til igjen] [Lukk]
□ Default: "Skann neste" (kamera gjenåpner automatisk, mengde resettes til 100g)
```

#### US-3.3: Bruker skanner ukjent strekkode
```
SOM: bruker
ØNSKER: rapportere ny vare som mangler i databasen
SÅ AT: jeg kan logge den likevel og hjelpe andre

Acceptance Criteria:
□ Produktoppslag returnerer 404 → "Produktet finnes ikkje"-skjerm
□ Tekst: "Vi fant ikkje denne strekkoden. Vil du legge den til?"
□ 2 CTA-knapper: [Ja, opprett] [Nei, skann igjen]
□ Klikk [Ja, opprett] → "Opprett produkt"-flow (minimum):
  1. Produktnavn (required)
  2. Kcal per 100g (required)
  3. Protein / karb / fett per 100g (required)
  4. [Fullfør senere] eller [Legg til nå]
□ Hvis [Fullfør senere]: produkt lagres lokalt som unverified + ingenting logges ennå
□ Hvis [Legg til nå]: produktet lagres + bruker går til mengde-velger (100g prefill)
□ Strekkode lagres med produktet
□ Når bruker senere fyller ut resten: opcional felter (sukker, fiber, salt, porsjon, bilde, kategori, merke)
□ Sync: unverified products queues til backend for moderation
```

---

### **Epic 4: Favoritter & Historikk**

#### US-4.1: Bruker merker vare som favoritt
```
SOM: bruker
ØNSKER: å fort kunne finne varer jeg spiser ofte
SÅ AT: jeg ikkje trenger å scanne dem på nytt

Acceptance Criteria:
□ Produktkort: ☆ / ★ toggle-knapp (øverst, høyre hjørne)
□ Tapp ☆ → ★ (og vice versa)
□ Favoritter lagres lokalt + synced
□ Home-skjermen: "Favoritter"-seksjon (hvis noen eksisterer)
□ Tapp favoritt → produktkort (100g prefill)
□ Max 50 favoritter for MVP (warn hvis overskredet)
```

#### US-4.2: Bruker trykker på skann-historikk
```
SOM: bruker
ØNSKER: å raskt finne varer jeg skannede nylig
SÅ AT: jeg kan logge dem igjen uten å skanne på nytt

Acceptance Criteria:
□ Home: "Nylig brukt"-panel (under Favoritter eller øvre del)
□ Viser siste 10–15 skannede produkter (descending by date)
□ Tapp produkt → produktkort (100g prefill)
□ "Slett fra historikk": long-press → delete-option
□ Historikken persisteres lokalt (min 30 dager)
```

---

### **Epic 5: Deling**

#### US-5.1: Bruker deler produkt via link
```
SOM: bruker
ØNSKER: å dele en vare jeg fant med en venn
SÅ AT: de kan importere den og bruke den

Acceptance Criteria:
□ Produktkort: [Del]-knapp
□ Tapp → [Kopier link] / [Del via...] (iOS share sheet)
□ Link-format: matlogg://share/{share_token} / https://matlogg.app/share/{share_token}
□ Backend generer engangs-token (TTL: 30 dager)
□ Token inneholder: product_id, sharer_id (anon option?)
□ Web-fallback: https://matlogg.app/share/{share_token}
  - Viser produktdetaljer (readonly)
  - CTA: [Åpne i MatLogg] → Deep link (hvis app installed)
  - CTA: [Last ned MatLogg] → App Store
□ Bruker mottar link → trykker → Deep link → app åpner produktkort
□ "Import"-handling: kopier produkt til brukerens lokale DB (som favoritt)
□ Revoke: token kan tilbakekalles (owner kan)
```

---

## 2.2 Detaljerte Flyter

### **Flow A: Komplette skanning + logging (Happy Path)**

```
┌─────────────────────────────────────────────────────────┐
│ 1. HOME-SKJERMEN                                        │
│ • Status: 500 / 2000 kcal                               │
│ • Måltidsrad: [Frokost] [LUNSJ] [Middag] [Snacks]        │
│ • Stor skann-knapp                                      │
│ • Logg-liste (tom eller med tidligere innslag)          │
└─────────────────────────────────────────────────────────┘
         ↓ [Bruker trykker skann-knapp]
┌─────────────────────────────────────────────────────────┐
│ 2. KAMERA-SKJERMEN                                      │
│ • Kamera åpen, venter på EAN-strekkode                  │
│ • "Hold kamera mot strekkode"                           │
│ • [Avbryt]-knapp (øvre venstre)                         │
└─────────────────────────────────────────────────────────┘
         ↓ [Strekkode detektert]
         ↓ [Haptic + lyd]
┌─────────────────────────────────────────────────────────┐
│ 3. PRODUKTKORT                                          │
│ • Produktbilde (eller placeholder)                      │
│ • Produktnavn: "Brød, rostaboost"                       │
│ • Merke / kategori                                      │
│ • Per 100g: 240 kcal, 8g protein, 45g carbs, 3g fat   │
│ • Mengde-felt: [100] g (editable)                       │
│ • Totalt: "100g = 240 kcal, 8g protein"                │
│ • Måltidsvalg (hvis ikkje valgt): [Velg måltid dropdown]│
│ • [Legg til]-knapp (primary color)                      │
│ • [Avbryt] (secondary)                                  │
│ • ☆ Favoritt-toggle (øverst høyre)                      │
└─────────────────────────────────────────────────────────┘
         ↓ [Bruker endrer mengde til 150g]
         ↓ [Legg til]-knapp kalkulert: 150 × 240/100 = 360 kcal
         ↓ [Bruker trykker "Legg til"]
┌─────────────────────────────────────────────────────────┐
│ 4. MINI-KVITTERING                                      │
│ ✓ "Brød, rostaboost (150g) lagt til LUNSJ"            │
│ • 360 kcal, 12g protein, 67.5g carbs, 4.5g fat         │
│ • [Skann neste] (primary, auto-focus)                   │
│ • [Legg til igjen] (secondary)                          │
│ • [Lukk]                                                │
│ • Haptic: double-tap, Lyd: beep (om ikke muted)        │
└─────────────────────────────────────────────────────────┘
         ↓ [Bruker trykker "Skann neste"]
         ↓ [Kamera gjenåpner, mengde=100g, måltid=LUNSJ]
         ↓ [Cycle repeats]
```

### **Flow B: "Ikke funnet"-flow**

```
┌─────────────────────────────────────────────────────────┐
│ 1. KAMERA                                               │
│ • Strekkode skannert                                    │
└─────────────────────────────────────────────────────────┘
         ↓ [API-oppslag returnerer 404]
         ↓ [Haptic: warning pulse, lyd: off]
┌─────────────────────────────────────────────────────────┐
│ 2. PRODUKT-IKKJE-FUNNET                                 │
│ "Produktet finnes ikkje. Vil du legge det til?"         │
│ • Strekkode-display: "5900234567890"                    │
│ • [Ja, opprett] (primary)                               │
│ • [Nei, skann igjen] (secondary)                        │
└─────────────────────────────────────────────────────────┘
         ↓ [Bruker trykker "Ja, opprett"]
┌─────────────────────────────────────────────────────────┐
│ 3. OPPRETT PRODUKT - STEG 1 (MINIMUM)                  │
│ "Fyll inn minimum-feltene"                              │
│ • Produktnavn: [____]                                   │
│ • Kcal per 100g: [____]                                 │
│ • Protein (g per 100g): [____]                          │
│ • Karbohydrater (g per 100g): [____]                    │
│ • Fett (g per 100g): [____]                             │
│ • [Fullfør senere] [Legg til og bruk nå]                │
└─────────────────────────────────────────────────────────┘
         ↓ [Bruker velger "Fullfør senere"]
         ↓ [Produkt lagres lokalt som "unverified"]
         ↓ [Bruker sendt tilbake til Home]
         ↓ [Synk-event queued for backend]
```

### **Flow C: Deling via link**

```
┌─────────────────────────────────────────────────────────┐
│ 1. PRODUKTKORT (som bruker A)                           │
│ • [Del]-knapp                                           │
└─────────────────────────────────────────────────────────┘
         ↓ [Bruker A trykker "Del"]
┌─────────────────────────────────────────────────────────┐
│ 2. DELING-OPTIONS                                       │
│ • [Kopier link] – Kopy til clipboard                    │
│   "matlogg://share/abc123xyz"                          │
│ • [Del via...] – iOS share sheet (iMessage, Mail, etc) │
│ • [Avbryt]                                              │
└─────────────────────────────────────────────────────────┘
         ↓ [Bruker A sender link til Bruker B via iMessage]
         ↓ [Bruker B mottar link, trykker på den]
         ↓ [Deep link activates matlogg://share/abc123xyz]
┌─────────────────────────────────────────────────────────┐
│ 3. APP RECEIVER (Bruker B)                              │
│ • Deep link handler triggered                          │
│ • Validerer token, API: GET /api/v1/shares/{token}    │
│ • Henter produktdetaljer                               │
│ • Viser produktkort + [Legg til i favoritter]           │
│ • Eller: [Skann & logg] (100g prefill, måltid prompt)  │
└─────────────────────────────────────────────────────────┘
         ↓ [Bruker B trykker "Legg til i favoritter"]
         ↓ [Produkt kopiert til lokal DB]
         ↓ "✓ Lagt til favoritter"
```

---

## 2.3 Edge Cases i Flyter

### **Scenario 1: Bruker skanner mens offline**
- Strekkode lagres i lokal event-kø
- Viser: "Offline – deler av databasen kan mangler. Vil søke når nett er tilbake."
- Tapping "Søk manuelt" → søkebar (navn-basert, lokal DB)
- Når nett tilbake: auto-sync av event-kø

### **Scenario 2: Bruker endrer mengde til 0g**
- Mengde-felt validerer: >0 og ≤10 kg
- Hvis 0: "Vær vennlig angi mengde > 0"
- Hvis >10 kg: "Det ser ut som mye – er du sikker?"

### **Scenario 3: Bruker oppgir kcal som ikke er rimelig**
- Validering: per 100g må være mellom 0 og 900 kcal (realistisk riktignok 0–800)
- Hvis >900: warning "Dette virker høyt – dobbeltkontroll. Fortsett?"

### **Scenario 4: Bruker logger samme vare dobbelt**
- Appen sier ingenting, men lagrer begge (kan endre siden da)
- Etter 2 min: "Hint: Vi merket at du logget Brød to ganger. Vil du slette en?"

### **Scenario 5: Produkt deles, deretter moderatoren sletter det**
- Mottaker: produktet forblir i lokal DB (kopi)
- Mottaker kan fortsette å bruke det offline
- Når online: warning "Dette produktet er fjernet fra fellesbibilioteket, men du kan fortsette å bruke din kopi"

---

## 2.4 Dataflyt & Synkronisering

```
┌──────────────────────────────────────────────────────────┐
│ LOCAL (iOS Device)                                       │
│ ┌────────────────────────────────────────────────────┐   │
│ │ SQLite: Products, Logs, Goals, Favorites, Events  │   │
│ │ (Offline-first)                                    │   │
│ └────────────────────────────────────────────────────┘   │
│         ↕ (enqueuer, background sync)                    │
│ ┌────────────────────────────────────────────────────┐   │
│ │ Event Queue (JSON):                                │   │
│ │ [{ op: "log", product_id, amount, meal, ... }]    │   │
│ └────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────┘
                         ↕ Network
┌──────────────────────────────────────────────────────────┐
│ BACKEND                                                  │
│ ┌────────────────────────────────────────────────────┐   │
│ │ POST /api/v1/sync                                  │   │
│ │ • Bruker-auth: JWT                                 │   │
│ │ • Body: { events: [...], device_timestamp, ... }  │   │
│ │ • Response: { success: [...], errors: [...] }     │   │
│ └────────────────────────────────────────────────────┘   │
│         ↓                                                 │
│ ┌────────────────────────────────────────────────────┐   │
│ │ PostgreSQL: users, logs, products, goals, etc      │   │
│ │ • Persisting canonical data                        │   │
│ │ • Moderation queue for unverified products         │   │
│ └────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────┘
```

---

## 2.5 Oppbygning av Onboarding (4 skjermbilder)

| Skjermbilder | Innhold |
|--------------|---------|
| **1. Velkommen** | "Hei, {navn}! Sett mål for i dag" + illustrasjon |
| **2. Måltype** | [Weight loss] [Maintain] [Gain] |
| **3. Kalorier** | Slider: 1200–3500 kcal/dag |
| **4. Makroer** | Protein %: slider, Carbs %: slider, Fat %: slider (sum=100%) |
| (Valgfri) **5. Vekt** | "Valgfri: Hva veier du i dag?" + [Hopp over] [Lagre] |
| **6. Klar** | "Du er klar til å starte! Trykk [Start]" |
