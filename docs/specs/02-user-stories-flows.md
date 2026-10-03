# MatLogg – Brukerhistorier & Detaljerte Flyter

> **Dokumentstatus:** Detaljert kravunderlag. For gjeldende overordnet
> informasjonsarkitektur, terminologi og UX-retning, se
> [`../design-and-user-flow.md`](../design-and-user-flow.md). Kode og
> [`../current-state.md`](../current-state.md) avgjør hva som er implementert.
> Eldre eksempler nedenfor kan beskrive planlagt eller erstattet atferd.

## 2.1 Brukerhistorier (User Stories)

Gjeldende tillegg for gjenbruk av gårsdagens enkeltmåltid, inkludert
akseptansekriterier, er beskrevet i [måltidsgjenbruk](../meal-reuse.md).
Gjeldende flyt og akseptansekriterier for navngitte, lagrede måltider er
beskrevet i [lagrede måltider](../saved-meals.md).

### **Epic 1: Autentisering & Onboarding**

#### US-1.1: Bruker velger lokal profil eller konto
```
SOM: ny bruker
ØNSKER: å kunne starte lokalt uten konto, eller logge inn med Apple/e-post
SÅ AT: jeg kan prøve kjerneverdien uten å dele unødvendige persondata

Acceptance Criteria:
□ Ny installasjon oppretter lokal profil automatisk etter sesjonsgjenoppretting; lokal bruk er tidsubegrenset
□ Apple Sign in og e-post/passord er tilgjengelig; Google er senere scope
□ E-postregistrering krever bare e-post og passord; navn er ikke påkrevd
□ Validering: e-post format, passord >8 tegn
□ Ny lokal profil åpner første logging direkte; konto er en sekundær inngang
□ Eksisterende lokale data knyttes aldri til konto uten eksplisitt bekreftelse
□ Sessionstoken lagres sikkert i Keychain (iOS)
□ Ingen cookies; kun JWT-bearer-token i Authorization-header
```

#### US-1.2: Første logging og valgfrie mål
```
SOM: ny bruker
ØNSKER: raskt kunne velge loggføring med eller uten mål
SÅ AT: jeg kan begynne på en måte som passer meg

Acceptance Criteria:
□ Første logging åpner søk med fokus, skann/manuell som alternativer og kort personverntekst
□ Små skjermer, liggende retning og store tekststørrelser kan scrolle som tilgjengelighetsfallback
□ Første logging krever ikke mål; mål settes senere under Profil → Daglige mål
□ Automatisk lokal oppstart oppretter ikke et skjult mål
□ Kalorier og tilgjengelige makroverdier vises også uten mål
□ Måltype: rolig nedgang / stabil vekt / rolig oppgang (bestemmer beregningsretning)
□ Kalorimål: 1200–4500 kcal/dag, i tråd med GoalCalculator (produktgrenser, ikke medisinsk anbefaling)
□ Makromål: generell profil eller egendefinerte gram for protein/karbohydrat/fett
□ Vekt, høyde, alder, kjønn/formelvariant og aktivitet er valgfrie personopplysninger
□ Automatisk estimat krever alder 18+, gyldig vekt/høyde og eksplisitt valg av kvinne- eller mannvarianten i voksenformelen
□ Manglende eller annet formelgrunnlag gir ikke et gjettet standardestimat; brukeren angir eget mål eller supplerer opplysningene
□ Makroprofilene følger NNR 2023-intervallene for voksne og omtales som generelle fordelinger, ikke individuelle råd
□ Målskjermen viser utkast før eksplisitt lokal lagring; eksisterende local-first synkhendelse brukes når et mål lagres
□ Input beholdes ved lagringsfeil, og brukeren kan prøve igjen
```

---

#### US-1.3: Bruker redigerer daglige mål

- Profil åpner et eget skjema; eksisterende kalorier og makroer bevares.
- Avbryt og avbrutt forslag skriver ingenting. Uendret lagring lager ingen ny synkhendelse.
- Kalorier valideres som heltall 1200–4500. Makroer krever endelige,
  ikke-negative gramverdier som kan vises trygt; tomt felt tolkes ikke som null.
- Beregn nytt forslag → Se forslag → Bruk forslaget oppdaterer bare utkastet.
- Forslag omtales som estimert startpunkt. Ufullstendig grunnlag, alder under 18
  eller manglende støttet formelvariant gir ingen automatisk kaloriverdi.
- Feil beholder input; vellykket lokal lagring oppdaterer profil og målstatus.
- Mål vises bare når brukeren har opprettet dem; næringsverdier er tilgjengelige
  i både synlig UI og tilgjengelighetstreet.
- Lagring virker uten nett, med eksisterende atomiske `goal.set`-hendelse.

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
□ Vedvarende «Loggfør»-knapp i bunnmenyen åpner søk, skanning og manuell registrering
□ Måltidskort tilbyr kontekstuell legg-til med måltidet forhåndsvalgt
□ Hvis ingen innslag i dag: "Ingen logget ennå"
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
□ Swipe for å slette uten dialog; kompakt melding med Angre gjenoppretter slettede varer samlet
```

---

### **Epic 3: Strekkode-Skanning**

#### US-3.1: Bruker skanner strekkode (happy path)
```
SOM: bruker
ØNSKER: scanne strekkode og raskt legge den til mitt måltid
SÅ AT: jeg ikkje bruker for mye tid på logging

Acceptance Criteria:
□ Tapp «Loggfør» → «Skann» → åpne kamera (AVFoundation)
□ Venter på EAN- eller GS1 Data Matrix-deteksjon (auto-trigger, ingen knapp)
□ For GS1 Data Matrix brukes bare validert GTIN (AI 01); dato, lot og andre sporbarhetsfelt lagres eller sendes ikke
□ Ved deteksjon av gyldig produktidentifikator: én lett haptisk puls + lyd (pling), utløst kun én gang
□ Oppslag mot Open Food Facts API v3 med app-identifiserende User-Agent
□ Hvis produkt finnes:
  - Umiddelbar produktkort-visning (hoppet over loading-state)
  - Mengde-felt prefylt: 100g
  - "Legg til"-knapp satt og klar
□ Treff caches lokalt med stabil identitet basert på kilde + strekkode
□ Ukjent strekkode og ufullstendig kcal-/makrogrunnlag vises som separate tilstander, begge med manuell registrering (se US-3.3)
□ Nettverksfeil tilbyr «Prøv igjen» og «Registrer manuelt»; ratebegrensning viser ventetid
□ Eksisterende OFF-produkter kan oppdateres manuelt fra produktkortet; lagrede data beholdes ved feil
□ Lagrede treff åpnes direkte. Nye oppslag viser ventestatus, og etter 3 sekunder vises en forklaring. Søk og manuell registrering er tilgjengelig under oppslaget; gamle svar forkastes når brukeren går videre.
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
  - Valgt dato (fortid, i dag eller fremtid)
  - Timestamp
□ Lokal DB-insert umiddelbar
□ Network sync enqueued (background)
□ Kompakt bekreftelse vises: "✓ 150 g Brød lagt til Lunsj"
□ Bekreftelsen viser "Lagret på enheten" og tilbyr [Angre]
□ Semantisk success-haptikk + beep etter vellykket lokal lagring
□ Bekreftelsen blokkerer ikke skjermen og forsvinner automatisk etter 4 sekunder
□ Ved skanning fortsetter kameraet automatisk med mengde reset til 100g
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
│ • Vedvarende Loggfør-knapp i bunnmenyen                 │
│ • Logg-liste (tom eller med tidligere innslag)          │
└─────────────────────────────────────────────────────────┘
         ↓ [Bruker trykker Loggfør → Skann]
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
│ 4. KOMPAKT BEKREFTELSE                                  │
│ ✓ "150 g Brød, rostaboost lagt til Lunsj"     [Angre] │
│   "Lagret på enheten"                                  │
│ • Ikke-modal, forsvinner etter 4 sekunder               │
│ • Haptikk: success, lyd: beep (om ikke muted)           │
└─────────────────────────────────────────────────────────┘
         ↓ [Kamera fortsetter, mengde=100g, måltid=LUNSJ]
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

## Navigasjonsforenkling (2026-10-02)

- Hjem → Se dagslogg åpner hele valgt dag med ett trykk. Måltidsnavn åpner valgt måltid.
- Synlige varer på Hjem åpner redigering direkte; mengdefelt og lagring gir tre trykk utenom skriving.
- Hjem, bunnmeny og dagslogg bruker samme Loggfør-ark og beholder dato/måltid.
- Registrer manuelt er alltid tilgjengelig og leder til lokal produktlagring og mengdevalg.
- Lagrede måltider har fast inngang også ved tom liste, og maler har synlig handlingsmeny.
- Gjenbruk i dagsloggen samler maloppretting og kopiering fra i går.
- Energi på Hjem krever ikke mål; eksisterende skjulvalg beholdes. Ingen ny datainnsamling.

### US-3.2 tillegg: antall porsjoner (2026-10-02)

- Velg en dokumentert porsjon eller hel pakke og angi antall med felt eller −/+.
- Eksempel: 2 × 37,5 g vises som 75 g og lagres med antall og historisk grunnlag.
- Antall, kilde/enhet og næring bevares etter omstart og ved redigering.
- Direkte gram/ml fungerer for varer uten egnet porsjonsgrunnlag.
- Egne nye porsjoner er utenfor dette leveransescope-et.

### Manuell registrering: næringsgrunnlag (2026-10-03)

- Velg 100 g, 100 ml eller porsjon/stykk før næringsverdier fylles inn.
- Porsjon/stykk krever navn og størrelse i g/ml og kan brukes som antall i produktkortet.
- Bytte av grunnlag med utfylte næringsfelt krever bekreftelse og ny inntasting.
- Registreringen fungerer offline og beholder brukerkilde og originalinput lokalt og i synkpayload.

Dette utvider tidligere avgrensning om ingen egne nye porsjoner for manuelt
opprettede produkter; generell porsjonseditor for andre produkter er fortsatt utenfor scope.
