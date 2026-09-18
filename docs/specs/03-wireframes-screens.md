# MatLogg – Skjermkart & iOS Tekstskisser

> **Dokumentstatus:** Detaljerte skjermreferanser. Gjeldende overordnet
> navigasjon, handlingshierarki og UX-regler finnes i
> [`../design-and-user-flow.md`](../design-and-user-flow.md), mens visuelle regler
> finnes i [`../design-system.md`](../design-system.md). ASCII-skisser og eldre
> beskrivelser nedenfor er referanser og kan ligge bak implementasjonen.

## 3.1 App-Arkitektur & Tab-struktur

```
┌─────────────────────────────────────────┐
│ MatLogg Root (TabView)                  │
├─────────────────────────────────────────┤
│ Tab 1: HJEM (dagsstatus og måltider)    │
│ Tab 2: SØK (råvarer, nylig, favoritter) │
│ Tab 3: LEGG TIL (handlingsmeny)         │
│ Tab 4: OVERSIKT (uke, makroer og utvikling) │
│ Tab 5: PROFIL (mål, trygghet og konto)  │
└─────────────────────────────────────────┘
```

---

## 3.2 Skjermkart (Wireframes)

### Profil

Profil bruker den samme varme, kortbaserte retningen som Hjem. Øverst vises
navn, initialer og antall måltidstyper logget i dag. Tre oversiktskort viser
reelle, lokale verdier for dagens måltider, favoritter og ventende synk; appen
skal ikke vise konstruerte streaks eller prestasjonstall.

«Dagens mål» viser lagrede kalori- og makromål. Trygg modus og de separate
valgene for å skjule kalorier eller mål gjelder også her. Hurtigmenyen gir
tilgang til mål, favoritter og innstillinger. Konto, personvern, eksport,
preferanser, trygghet og synk beholdes samlet under Innstillinger.

Profilkort og menyrader skal støtte Dynamic Type, VoiceOver og minst 44 × 44 pt
trykkflate. Ved store tekststørrelser stables oversiktskortene vertikalt.

### **SKJERM 1: Home (Main)**

Home bruker en varm, kortbasert retning. Toppområdet viser MatLogg, dato og
profil. Deretter følger «Dagens matinntak», separate søk- og skanneknapper og fire
alltid synlige måltidskort i rekkefølgen frokost, lunsj, middag og kveldsmat.
Kveldsmat er presentasjonsnavnet for den kanoniske lagringsverdien `snacks`.
En stor sentral «Loggfør»-knapp åpner et bunnark med søk, skanning, måltidsvalg
og hurtigvalg fra favoritter og nylig brukte produkter.
Kortene viser inntil tre innslag, mengde og valgfri kaloriverdi. Trykk åpner
dagens logg filtrert på måltidet; tomme kort har en tydelig legg-til-handling.
Trygg modus skal fjerne kalorier og mål uten å etterlate avslørende etiketter.

Tilstandskrav for Home, hurtigvalg og søk:

- Før data er lest, vises en egen lastingstilstand; tomtilstand skal ikke blinke under lasting.
- Manglende mål eller dagsoversikt forklares uten å blokkere matlogging.
- Ventende synk vises som lokalt lagret og skal aldri fremstilles som tapt data.
- Søket skiller mellom ingen treff, lagrede treff og nettverksfeil. Nettverksfeil beholder søket og tilbyr «Prøv igjen» og strekkodeskanning.
- Hurtigvalg skiller mellom første gangs tomtilstand og en feil som kan prøves på nytt.
- Ved lokal lagringsfeil beholdes mengde og måltid, og feilen vises ved «Legg til»-handlingen med eksplisitt retry.
- Produktnavn opprettet av bruker er begrenset til 80 tegn; skjemaet viser tegnantall og forklarer overskridelse.
- Normal tekst skal ha minst 4,5:1 kontrast, stor tekst og nødvendige UI-symboler minst 3:1. Tekst på sterke makrofarger bruker mørk `onVibrant`, mens handlingslenker bruker det kontrastverifiserte `action`-tokenet.
- Interaktive elementer skal ha et effektivt trykkområde på minst 44 × 44 pt, også når det synlige ikonet eller chipen er mindre.
- Loggingarket viser alltid «Logg til: [valgt måltid]». Tidspunktet foreslår standardmåltid, mens inngang fra et måltidskort overstyrer dette med kortets måltid.
- Søk og strekkodeskanning presenteres som separate, tekstmerkede handlinger. Den sentrale faneknappen heter «Loggfør», og statistikkfanen heter «Oversikt».
- Når ingen måltider er registrert, brukes «Ingen logget ennå» fremfor en fremdriftsteller som kan oppfattes som et krav.

```
┌─────────────────────────────────────────────────────┐
│                   MatLogg                      12:34│
│  🔔  Tirsdag, 21 jan                                │
├─────────────────────────────────────────────────────┤
│                                                      │
│         ┌─────────────────────────────────┐          │
│         │      500 / 2000 kcal             │          │
│         │          ●●●●○ (25%)             │          │
│         │                                  │          │
│         │  P: 40g / 150g  C: 95g / 250g   │          │
│         │  F: 15g / 65g                    │          │
│         └─────────────────────────────────┘          │
│                                                      │
├─ MÅLTIDER ────────────────────────────────────────┤
│ [Frokost] [LUNSJ] [Middag] [Snacks]                │
├─ LUNSJ ────────────────────────────────────────────┤
│ ┌──────────────────────────────────────────────┐   │
│ │ Pålegg, salami (50g)          170 kcal       │   │
│ │                              ▶ 45°C swipe-del │   │
│ └──────────────────────────────────────────────┘   │
│ ┌──────────────────────────────────────────────┐   │
│ │ Brød, rostaboost (150g)       360 kcal       │   │
│ └──────────────────────────────────────────────┘   │
│                                                      │
├─ FROKOST ──────────────────────────────────────────┤
│ ┌──────────────────────────────────────────────┐   │
│ │ Melk, H-melk (200ml)          130 kcal       │   │
│ └──────────────────────────────────────────────┘   │
│                                                      │
├─ MIDDAG ───────────────────────────────────────────┤
│  (Tom – ingen innslag)                              │
│                                                      │
├─────────────────────────────────────────────────────┤
│                                                      │
│        ┌─────────────────────────────┐               │
│        │                             │               │
│        │         [📱 SKANN]           │               │
│        │                             │               │
│        └─────────────────────────────┘               │
│                                                      │
│  [+ Legg til manuelt] [Historikk]                   │
│                                                      │
└─────────────────────────────────────────────────────┘
```

**Beskrivelse:**
- **Topp:** Dato + 🔔 ikon (stille/aktiv)
- **Status-ring:** Stor sirkel-progress-ring (kcal %) – farge basert på prosent
  - Grønn: 0–50%
  - Gul: 50–100%
  - Rød: >100%
- **Makro-breakdown:** 3 linjer, hver med navn / gjeldende / mål
- **Måltidsrad:** 4 knapper, valgt er highlighted (bold + bakgrunnsfarge)
- **Logg-liste:** Organisert etter måltid, hver innslag editable/swipe-to-delete
- **Stor skann-knapp:** 5 cm × 5 cm, blå, med kamera-ikon
- **Sekundær-knapper:** "Legg til manuelt" + "Historikk"

---

### **SKJERM 2: Kamera-visning (Scan)**

```
┌─────────────────────────────────────────────────────┐
│  ✕                                           🔦      │
│                                                      │
│                                                      │
│                                                      │
│          ┌─────────────────────────────┐              │
│          │      [KAMERA-FEED]          │              │
│          │                             │              │
│          │    ▢ SCAN ZONE              │              │
│          │                             │              │
│          └─────────────────────────────┘              │
│                                                      │
│                                                      │
│                                                      │
│        "Hold kamera mot strekkode"                  │
│                                                      │
│  [Søk manuelt]              [Historikk]            │
│                                                      │
└─────────────────────────────────────────────────────┘
```

**Beskrivelse:**
- **Topp:** ✕-knapp (avbryt) + 🔦-knapp (torch)
- **Kamera-feed:** Fullskjerm, auto-fokus
- **Scan-zone:** Retangel indikator (sentrert, gult frame når scanning)
- **Feedback:** Når strekkode detektert: grønt frame + haptic + lyd
- **Bunn:** "Søk manuelt" (fallback søk) + "Historikk" (rask-adgang)

---

### **SKJERM 3: Produktkort (Product Details)**

```
┌─────────────────────────────────────────────────────┐
│  ← Back                                         ★☆   │
├─────────────────────────────────────────────────────┤
│                                                      │
│          ┌─────────────────────────────┐              │
│          │    [Produktbilde/Icon]      │              │
│          │  (eller grå placeholder)     │              │
│          └─────────────────────────────┘              │
│                                                      │
│  Brød, Rostaboost                                   │
│  Merke: Kneippehuset  •  Kategori: Bakeri          │
│  Strekkode: 5900423000890                           │
│                                                      │
├─ NÆRING PER 100G ──────────────────────────────────┤
│  Energi:        240 kcal                            │
│  Protein:       8 g                                 │
│  Karbohydrater: 45 g                                │
│  Fett:          3 g                                 │
│  (Sukker, fiber, salt – om tilgjengelig)            │
│                                                      │
├─ STANDARD PORSJONSSTØRRELSER ──────────────────────┤
│  [ Skive (35g) ]  [ 100g ] [Bolle (65g)]           │
│                                                      │
├─ VELG MENGDE ──────────────────────────────────────┤
│  [−] 100 [+] g                                      │
│      or                                             │
│  ═════════════ Slider (0–1000g)  ═════════════     │
│                                                      │
│  Total: 240 kcal | P: 8g | C: 45g | F: 3g          │
│                                                      │
├─ MÅLTIDSVALG ──────────────────────────────────────┤
│  Måltid: [LUNSJ ▼] (eller Frokost, Middag, Snacks)  │
│                                                      │
├─────────────────────────────────────────────────────┤
│                                                      │
│  [━━━━━ LEGG TIL ━━━━━]                             │
│  [  Avbryt  ]                                       │
│                                                      │
│  ☆ Legg til i favoritter                            │
│                                                      │
└─────────────────────────────────────────────────────┘
```

**Beskrivelse:**
- **Topp:** Back-knapp + favoritt-toggle (☆/★)
- **Bilde:** Produktbilde (fra barcode DB eller placeholder)
- **Info:** Produktnavn, merke, kategori, strekkode
- **Næring:** Per 100g (alltid basis)
- **Porsjonsstørrelser:** Buttons, viser hvis tilgjengelig (Matvaretabellen)
- **Mengde-velger:** Numerisk input + stepper (default 100g)
- **Totalt:** Live-beregnet, oppdateres når mengde endres
- **Måltidsvalg:** Dropdown (eller bare visning av "current meal")
- **Knapper:**
  - [LEGG TIL] – primary, fyllt blå
  - [Avbryt] – secondary, outline
  - [☆ Legg til i favoritter] – tertiary link-stil

---

### **SKJERM 4: Mini-Kvittering (Success Receipt)**

```
┌─────────────────────────────────────────────────────┐
│                                                      │
│                     ✓                                │
│                                                      │
│          Brød, Rostaboost                            │
│          150g  →  360 kcal                           │
│          Lunsj                                       │
│                                                      │
│       Protein: 12g | Carbs: 67.5g | Fat: 4.5g      │
│                                                      │
├─────────────────────────────────────────────────────┤
│                                                      │
│  [━━ SKANN NESTE ━━]                                 │
│  [  Legg til igjen  ]                                │
│  [      Lukk       ]                                 │
│                                                      │
└─────────────────────────────────────────────────────┘
```

**Beskrivelse:**
- **Bakgrunn:** Lett animasjon (scale-in eller fade-in)
- **Ikon:** Grønt ✓-tegn
- **Tekst:** Produktnavn, mengde, kcal, måltid, makro-detaljer
- **Knapper:**
  - [SKANN NESTE] – primary, auto-fokusert, kamera gjenåpner (mengde resettes)
  - [Legg til igjen] – secondary
  - [Lukk] – tertiary, lukker tilbake til Home
- **Timing:** Auto-dismiss etter 5 sekunder hvis brukeren ikkje gjør noe

---

### **SKJERM 5: "Ikke funnet"-Flow**

```
┌─────────────────────────────────────────────────────┐
│  ✕ Avbryt                                            │
├─────────────────────────────────────────────────────┤
│                                                      │
│  ⚠️                                                  │
│  Produktet finnes ikkje                              │
│                                                      │
│  Vil du legge det til i databasen?                  │
│                                                      │
│  Strekkode: 5900234567890                            │
│                                                      │
├─────────────────────────────────────────────────────┤
│                                                      │
│  [━━━ JA, OPPRETT ━━━]                               │
│  [  NEI, SKANN IGJEN  ]                              │
│                                                      │
└─────────────────────────────────────────────────────┘
```

**Beskrivelse:**
- **Ikon:** Varningstrekant (⚠️) eller spørsmålstegn
- **Tekst:** Kort beskrivelse
- **Strekkode-display:** Monospace, for klarhet
- **Knapper:**
  - [JA, OPPRETT] – primary
  - [NEI, SKANN IGJEN] – secondary, lukkerkamera igjen

---

### **SKJERM 6: Opprett produkt (Steg 1: Minimum)**

```
┌─────────────────────────────────────────────────────┐
│  ← Avbryt                     Steg 1 av 2  Fullfør  │
├─────────────────────────────────────────────────────┤
│                                                      │
│  Fyll inn minimum-feltene                            │
│                                                      │
│  Produktnavn *                                      │
│  ┌──────────────────────────────────────────────┐   │
│  │ (f.eks. "Kjøttboller, IKEA")                 │   │
│  └──────────────────────────────────────────────┘   │
│                                                      │
│  Energi (kcal per 100g) *                            │
│  ┌──────────────────────────────────────────────┐   │
│  │ (f.eks. 240)                                 │   │
│  └──────────────────────────────────────────────┘   │
│                                                      │
│  Protein (g per 100g) *                              │
│  ┌──────────────────────────────────────────────┐   │
│  │ 8                                            │   │
│  └──────────────────────────────────────────────┘   │
│                                                      │
│  Karbohydrater (g per 100g) *                        │
│  ┌──────────────────────────────────────────────┐   │
│  │ 45                                           │   │
│  └──────────────────────────────────────────────┘   │
│                                                      │
│  Fett (g per 100g) *                                 │
│  ┌──────────────────────────────────────────────┐   │
│  │ 3                                            │   │
│  └──────────────────────────────────────────────┘   │
│                                                      │
│  Strekkode (auto-fylt)                               │
│  ┌──────────────────────────────────────────────┐   │
│  │ 5900234567890                                │   │
│  └──────────────────────────────────────────────┘   │
│                                                      │
├─────────────────────────────────────────────────────┤
│                                                      │
│  [━ FULLFØR SENERE ━]  [LEG TIL OG BRUK NÅ]        │
│                                                      │
└─────────────────────────────────────────────────────┘
```

**Beskrivelse:**
- **Header:** "Steg 1 av 2", Avbryt-knapp, "Fullfør"-status
- **Felt:** Alle required (marked with *)
- **Input-typer:** Text (navn), numeric (kcal, makro), readonly (strekkode)
- **Knapper:**
  - [FULLFØR SENERE] – secondary, lagrer som "unverified"
  - [LEGG TIL OG BRUK NÅ] – primary, go to step 2 eller direkte logging

---

### **SKJERM 7: Opprett produkt (Steg 2: Valgfritt)**

```
┌─────────────────────────────────────────────────────┐
│  ← Tilbake                    Steg 2 av 2  Ferdig   │
├─────────────────────────────────────────────────────┤
│                                                      │
│  Legg til detaljer (valgfritt)                       │
│                                                      │
│  Bilde (foto eller URL)                              │
│  ┌──────────────────────────────────────────────┐   │
│  │ [Kameraikon] Ta foto eller velg fra galleriet│   │
│  └──────────────────────────────────────────────┘   │
│                                                      │
│  Merke                                               │
│  ┌──────────────────────────────────────────────┐   │
│  │ (f.eks. "IKEA")                              │   │
│  └──────────────────────────────────────────────┘   │
│                                                      │
│  Kategori                                            │
│  ┌──────────────────────────────────────────────┐   │
│  │ [Velg kategori ▼] – Kjøtt, Meieri, Bakeri  │   │
│  └──────────────────────────────────────────────┘   │
│                                                      │
│  Sukker (g per 100g)                                 │
│  ┌──────────────────────────────────────────────┐   │
│  │ 5                                            │   │
│  └──────────────────────────────────────────────┘   │
│                                                      │
│  Fiber (g per 100g)                                  │
│  ┌──────────────────────────────────────────────┐   │
│  │ 2                                            │   │
│  └──────────────────────────────────────────────┘   │
│                                                      │
│  Natrium (mg per 100g)                               │
│  ┌──────────────────────────────────────────────┐   │
│  │ 500                                          │   │
│  └──────────────────────────────────────────────┘   │
│                                                      │
│  Standard porsjonsstørrelser                         │
│  ┌──────────────────────────────────────────────┐   │
│  │ Skive (35g) | Bolle (65g) | [+ Legg til]    │   │
│  └──────────────────────────────────────────────┘   │
│                                                      │
├─────────────────────────────────────────────────────┤
│                                                      │
│  [━━━━━━ FERDIG ━━━━━━]                              │
│                                                      │
└─────────────────────────────────────────────────────┘
```

---

### **SKJERM 8: Historikk-Panel (Scan History)**

```
┌─────────────────────────────────────────────────────┐
│  ✕ Lukk                          Historikk         │
├─────────────────────────────────────────────────────┤
│                                                      │
│  Nylig brukt (siste 10 varer)                       │
│                                                      │
│  ┌──────────────────────────────────────────────┐   │
│  │ Brød, Rostaboost                      ⋯⋯⋯   │   │
│  │ 150g used 2h ago                             │   │
│  └──────────────────────────────────────────────┘   │
│                                                      │
│  ┌──────────────────────────────────────────────┐   │
│  │ Melk, H-melk                          ⋯⋯⋯   │   │
│  │ 200ml used 4h ago                            │   │
│  └──────────────────────────────────────────────┘   │
│                                                      │
│  ┌──────────────────────────────────────────────┐   │
│  │ Pålegg, salami                        ⋯⋯⋯   │   │
│  │ 50g used yesterday                           │   │
│  └──────────────────────────────────────────────┘   │
│                                                      │
│  ┌──────────────────────────────────────────────┐   │
│  │ Epler, Granny Smith                   ⋯⋯⋯   │   │
│  │ 150g used 2 days ago                         │   │
│  └──────────────────────────────────────────────┘   │
│                                                      │
│  ...                                                 │
│                                                      │
├─────────────────────────────────────────────────────┤
│                                                      │
│  [Tøm historikk]                                    │
│                                                      │
└─────────────────────────────────────────────────────┘
```

**Beskrivelse:**
- **Header:** "Historikk", ✕-knapp (close)
- **Items:** Produktnavn, brukt mengde, tid siden sist brukt
- **Tapp item:** Åpner produktkort (100g prefill igjen, ikke forrige mengde)
- **Long-press item:** [Slett fra historikk] option
- **Tøm historikk:** Knapp nederst for å fjerne alt

---

### **SKJERM 9: Favoritter**

Favoritter kan åpnes direkte fra Profil. Listen lastes fra lokal lagring og
skal derfor fungere uten nett. Trykk på en rad åpner produktkortet med 100 g
som utgangspunkt. Når produktkortet lukkes, lastes listen på nytt slik at en
vare som ikke lenger er favoritt forsvinner med en gang. En tom liste viser
«Ingen favoritter ennå» og en handling til matsøket.

```
┌─────────────────────────────────────────────────────┐
│  ★ Favoritter                                  12:34│
├─────────────────────────────────────────────────────┤
│                                                      │
│  ┌──────────────────────────────────────────────┐   │
│  │ ★ Brød, Rostaboost                           │   │
│  │   240 kcal per 100g                          │   │
│  │   P: 8g  C: 45g  F: 3g                       │   │
│  └──────────────────────────────────────────────┘   │
│                                                      │
│  ┌──────────────────────────────────────────────┐   │
│  │ ★ Melk, H-melk                               │   │
│  │   65 kcal per 100ml                          │   │
│  │   P: 3.2g  C: 4.8g  F: 3.5g                  │   │
│  └──────────────────────────────────────────────┘   │
│                                                      │
│  ┌──────────────────────────────────────────────┐   │
│  │ ★ Epler, Granny Smith                        │   │
│  │   52 kcal per 100g                           │   │
│  │   P: 0.3g  C: 14g  F: 0.2g                   │   │
│  └──────────────────────────────────────────────┘   │
│                                                      │
│                                                      │
│                                                      │
└─────────────────────────────────────────────────────┘
```

---

### **SKJERM 10: Innstillinger**

```
┌─────────────────────────────────────────────────────┐
│  ⚙️ Innstillinger                                    │
├─────────────────────────────────────────────────────┤
│                                                      │
│  TILBAKEMELDINGER                                    │
│  Haptic-feedback ved skann    [ON ─ OFF]            │
│  Lyd ved skann                [ON ─ OFF]            │
│  Haptic-feedback ved lagring  [ON ─ OFF]            │
│  Lyd ved lagring              [ON ─ OFF]            │
│                                                      │
│  KONTO                                               │
│  Bruker: nithu@example.com                           │
│  [Endre passord]                                    │
│  [Slette konto]                                     │
│                                                      │
│  DATA                                                │
│  [Eksport data]                                     │
│  [Slett logg for i dag]                             │
│  [Slett all logg]                                   │
│                                                      │
│  OM                                                  │
│  MatLogg v1.0.0                                      │
│  [Betingelser]                                      │
│  [Personvern]                                       │
│  [Kontakt oss]                                      │
│                                                      │
├─────────────────────────────────────────────────────┤
│                                                      │
│  [━━━━ LOGG UT ━━━━]                                 │
│                                                      │
└─────────────────────────────────────────────────────┘
```

---

## 3.3 Navigasjon & Navigation Stack

```
TabView (Root)
├─ HomeTab
│  ├─ HomeView
│  │  ├─→ CameraView (Full screen)
│  │  ├─→ ProductDetailView
│  │  │   └─→ CreateProductView (if "not found")
│  │  ├─→ HistoryPanelView
│  │  └─→ ManualAddView
│  └─ (logged-in user context)
│
├─ LoggerTab
│  ├─ LogHistoryView (Day view / List)
│  │  └─→ LogDetailView (edit/delete)
│  └─ (future: Week/Month view)
│
├─ FavoritesTab
│  ├─ FavoritesListView
│  │  └─→ ProductDetailView
│  └─ (share, search, etc.)
│
└─ SettingsTab
   ├─ SettingsView
   │  ├─→ AccountView
   │  │   └─→ ChangePasswordView
   │  ├─→ NotificationPreferencesView
   │  └─→ AboutView
   │
   └─ (Root: Auth/Onboarding if not logged in)
      ├─ LoginView
      ├─ SignUpView
      └─ OnboardingView (4 screens)
```

---

## 3.4 Modal & Sheet Presentasjon

| Situation | Presentation | Dismiss |
|-----------|--------------|---------|
| Kamera-skanning | Full screen | Avbryt-knapp, back gesture |
| Mini-kvittering | Bottom sheet (50% height) | Auto-dismiss (5s) eller Lukk |
| Søk manuelt | Sheet (half-screen) | Back / Avbryt |
| Historikk-panel | Sheet (70% height) | ✕ eller back gesture |
| "Ikke funnet" | Alert / Sheet | "Ja" / "Nei" |
| Favoritt-share | Action sheet (iOS) | Valg eller Avbryt |
| Slette-konfirmasjon | Alert dialog | OK / Avbryt |
