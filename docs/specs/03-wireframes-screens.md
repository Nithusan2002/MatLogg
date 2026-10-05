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
│ Tab 2: SØK (favoritter, nylig brukt) │
│ Tab 3: LEGG TIL (handlingsmeny)         │
│ Tab 4: OVERSIKT (uke, makroer og utvikling) │
│ Tab 5: PROFIL (mål, trygghet og konto)  │
└─────────────────────────────────────────┘
```

---

## 3.2 Skjermkart (Wireframes)

### Første logging

To sveipbare introsider viser «Matlogging gjort enkelt» med et fotografi av
en frokostskål og «Oversikt på dine premisser» med et pizzafoto. Native
sidevisning følger sveiping kontinuerlig. Begge har
kort, sentrert tekst og «Uten konto. Lagres på denne iPhonen.». Innholdet er
rullbart uten fast sidehøyde. Sideindikatorene er knapper med VoiceOver-labels.
«Neste» åpner side 2; «Logg din første matvare» og «Hopp over intro» åpner logging.
Knappene ligger over nederste safe area. «Gå til Hjem» finnes på loggingssteget.
Informasjon om manglende skybackup, eksport og personvern følger søket.

«Logg din første matvare» åpner deretter søk med fokus. Kort informasjon om lokal lagring,
valgfri konto/mål og personvernlenke ligger sammen med søkekontrollene i
en rullbar liste. «Søk», «Skann» og «Manuelt» står på samme flate; store
tekststørrelser bruker vertikal layout. Lokale treff prioriteres foran
forklaringstekst og tomme favoritt-/historikkseksjoner.

«Logg inn» er sekundær. «Gå til Hjem» avslutter førstegangsvisningen uten
mål eller logging. Produktkortet gjenbrukes, og vellykket lokal lagring
åpner Hjem med kvittering og Angre. Ingen oppsummering krever nytt trykk.

Makroene i energikortet på Hjem viser registrert mengde og mål på samme
linje, for eksempel «65 / 120 g», under næringsstoffets navn. Uten mål vises
bare registrert mengde. Ved tilgjengelighetstekststørrelser stables makroene
vertikalt, og VoiceOver leser inntak og mål eksplisitt.

### Profil

Profil bruker den samme varme, kortbaserte retningen som Hjem. Øverst vises
navn, initialer og en eksplisitt inngang til Personlige detaljer. Navn er valgfritt
og redigeres med Avbryt/Lagre i Personlige detaljer. Det lagres per profil på
enheten og vises foran eventuelt kontonavn; det synkroniseres ikke.

«Daglige mål» er første rad i menyen, over Favoritter og Innstillinger.
«Hjelp og støtte» er siste rad, under Innstillinger, med `questionmark.circle`
og samme menyradstil. Den åpner en side med lokale vanlige spørsmål,
der svarene er lukket fra start og foldes ut/inn per spørsmål,
e-postkontakt og appversjon/build. Kontakt krever ikke konto og legger ikke
automatisk ved brukerdata. Adressen kan kopieres dersom e-postappen ikke åpnes.
Raden viser lagret kalorimål i kcal per dag, eller «Valgfritt · Sett opp mål»
når mål mangler. Hele raden åpner målskjermen, som viser detaljene for kalorier
og makroer. Underteksten bryter over flere linjer ved stor tekst.
En kort tekst forklarer lokal lagring uten å presentere synkhendelser som
antall lagrede matvarer.

Profilkortet er den faste inngangen til Personlige detaljer, uten duplisert
lenke i Innstillinger. Målraden åpner Daglige mål.
Innstillinger grupperer personvern, visning/tilbakemelding, data/lagring
og konto. Eksport forklarer hvilke datasett som følger med og viser fremdrift
og feil. Personlige detaljer har et eksplisitt utkast, påkrevd fødselsdato ved lagring,
feltvalidering og lukker først etter vellykket lagring. Skjermen bruker to
samlede kort, «Profil» og «Grunnlag for målforslag», med kompakte feltrader
og vertikalt oppsett ved stor tekst. Fødselsdato velges i en datovelger med appens tema
og eksplisitt bekreftelse, uten mulighet for fjerning; hovedraden beholder samme etikett.
Vekt og høyde åpner et kort med horisontal tallskala, fast markør, direkte
inntasting og «Bruk verdi». Avbryt beholder utkastet; «Fjern opplysningen»
tømmer feltet. Valget lagres først med profilens «Lagre». Vekt til beregning
holdes tydelig atskilt fra vekthistorikken.

Profilkort og menyrader skal støtte Dynamic Type, VoiceOver og minst 44 × 44 pt
trykkflate. Aktivitetsvalg kan rulles ved store tekststørrelser.

### **SKJERM 1: Home (Main)**

Home bruker en varm bakgrunn med måltidsloggen som hovedinnhold. Toppområdet
starter med datovelgeren. Appnavn og profilknapp vises ikke her; Profil åpnes fra bunnmenyen. Lokal lagring vises under Profil → Innstillinger → Data og lagring, uten permanent banner på Hjem. Når synk er tilgjengelig, vises eventuell status for ventende endringer og feil før en tidsstyrt hilsen for i dag («Dagsoversikt» for andre datoer), et valgfritt
samlet dagsstatusfelt med valgfri næring og vann som nederste rad. Når næring er skjult, vises bare vannraden i samme flate. Deretter følger måltidsoverskriften og fire kompakte måltidsseksjoner: frokost, lunsj, middag og kveldsmat. Seksjonene har
lyse kortflater med 24 pt hjørner, 16 pt padding og diskret skygge. Etter måltidene følger personlige hurtigvalg.
Generiske søk- og skanneknapper dupliseres ikke på Hjem.
Kveldsmat er presentasjonsnavnet for den kanoniske lagringsverdien `snacks`.
Den sentrale «Loggfør»-knappen i bunnmenyen åpner bunnarket med eksisterende loggingvalg.
En ferdig lastet dag uten matlogger viser «Ingen logget ennå» og «Loggfør første
måltid» under måltidsoverskriften, før de fire kortene. Handlingen bruker valgt
dato og vises også når målstatus er skjult. Den vises ikke under lasting, ved
feil eller på dager med matlogger. Ingen fast, stor loggknapp vises over måltidene.
Måltidsseksjonene viser inntil tre innslag med produktbilde og mengde, samt en
samlet næringsrad. Trykk på en fylt seksjon åpner valgt måltid for valgt dato;
tomme seksjoner har en tydelig «Legg til»-handling. Gjenbruk og angre beholdes.

Tilstandskrav for Home, hurtigvalg og søk:

- Før data er lest, vises en egen lastingstilstand; tomtilstand skal ikke blinke under lasting. Ved oppdatering av samme profil og dato beholdes ferdig innhold med en diskret «Oppdaterer …»-indikator. Profil- eller datobytte fjerner tidligere kontekst før nye svar publiseres.
- Lagrede måltider, skannehistorikk og innholdet i «Lagre som måltid» har egne indikatorer fra første visning. Morgeninnsjekk viser «Henter innsjekk …» mens knappen er deaktivert. Feil ved bibliotek-/oversiktslasting tilbyr «Prøv igjen» og skal ikke fremstå som en tom liste.
- Lokale søketreff blir brukbare før kataloglasting er ferdig. Katalogen lastes samtidig med lokale oppslag; ukesoversikten henter perioden samlet. Uavhengige seksjoner oppdateres hver for seg.
- Manglende mål eller dagsoversikt forklares uten å blokkere matlogging.
- Ventende synk vises som lokalt lagret og skal aldri fremstilles som tapt data.
- Søk-fanen har direkte søk, favoritter og nylig loggede varer. Tomme seksjoner skjules; uten historikk eller favoritter vises «Søk etter en matvare for å komme i gang.», også ved første logging. Råvarer vises kun som søkeresultater. Lokale treff vises mens brukeren skriver; eksterne treff hentes eksplisitt. Søket skiller mellom ingen treff, lagrede treff og nettverksfeil. Nettverksfeil beholder lokale treff og søket, og tilbyr «Prøv igjen», strekkodeskanning og manuell produktregistrering.
- Måltidskortene på Hjem og produktradene i dagsloggens måltidsvisning viser 52 pt produktbilder med 2 pt innvendig luft fra produktets lagrede bilde-URL eller lokale bilde, med hele bildet synlig. Manglende bilder bruker et nøytralt matikon i samme ramme. Hjem bruker måltidssymboler i 30 pt sirkler med svak måltidsfarge: soloppgang, sol, bestikk og måne med stjerner. Dekorative symboler skjules for VoiceOver; måltidsnavn og «Legg til» beholder minst 44 pt trykkflate. Tomme kort viser «Ikke logget ennå». Søkeresultater beholder kompakte bilder.
- Produktlister viser en kompakt thumbnail når et produktbilde finnes. Manglende eller mislykket bilde bruker en nøytral placeholder uten å flytte tekst eller endre radhøyden.
- Hurtigvalg skiller mellom første gangs tomtilstand og en feil som kan prøves på nytt.
- Ved lokal lagringsfeil beholdes mengde og måltid, og feilen vises ved «Legg til»-handlingen med eksplisitt retry.
- Produktnavn opprettet av bruker er begrenset til 80 tegn; skjemaet viser tegnantall og forklarer overskridelse.
- Normal tekst skal ha minst 4,5:1 kontrast, stor tekst og nødvendige UI-symboler minst 3:1. Tekst på sterke makrofarger bruker mørk `onVibrant`, mens handlingslenker bruker det kontrastverifiserte `action`-tokenet.
- Interaktive elementer skal ha et effektivt trykkområde på minst 44 × 44 pt, også når det synlige ikonet eller chipen er mindre.
- Loggingarket viser alltid «Logg til: [valgt måltid]». Tidspunktet foreslår standardmåltid, mens inngang fra et måltidskort overstyrer dette med kortets måltid.
- Søk og strekkodeskanning presenteres som separate, tekstmerkede handlinger i Loggfør-arket og Søk-fanen. De dupliseres ikke som en egen handlingsrad på Hjem. Den sentrale faneknappen heter «Loggfør», og statistikkfanen heter «Utvikling».
- «Registrer manuelt» ligger som en sekundær knapp i full bredde rett under Søk og Skann strekkode, før listene, i alle søketilstander.
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
│ "Hold kamera mot strekkode eller firkantet kode"  │
│                                                      │
│  [────────── Søk etter vare ──────────]             │
│  [──────── Registrer manuelt ─────────]             │
│                                                      │
└─────────────────────────────────────────────────────┘
```

**Beskrivelse:**
- **Topp:** ✕-knapp (avbryt) + 🔦-knapp (torch)
- **Kamera-feed:** Fullskjerm, auto-fokus
- **Scan-zone:** Retangel indikator (sentrert, gult frame når scanning)
- **Feedback:** Når strekkode detektert: grønt frame + haptic + lyd
- **Bunn:** "Søk etter vare" (fallback søk) + "Registrer manuelt"

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
- **Katalogoppdatering:** OFF-produkter med OFF-næringsgrunnlag viser «Sist hentet» og «Hent oppdaterte produktdata». Handlingen viser lasting og resultat som tekst, og deaktiveres under oppdatering eller logging. Logging med eksisterende data fungerer under automatisk oppdatering. Egne varer får ikke denne handlingen.
- **Feil ved skanning:** «Vi fant ikke produktet» og «Produktet mangler næringsdata» er separate meldinger med «Registrer manuelt». Tilkoblingsfeil tilbyr også «Prøv igjen»; ratebegrensning viser ventetid.
- **Tilgjengelighet:** Oppdateringshandlingen bruker tekstmerket knapp, minst 44 pt touchflate og Dynamic Type. Tilstand formidles med tekst, ikke bare farge.
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

### **SKJERM 4: Kompakt loggbekreftelse**

```
┌─────────────────────────────────────────────────────┐
│ ✓ 150 g Brød, Rostaboost lagt til Lunsj    [Angre] │
│   Lagret på enheten                                 │
└─────────────────────────────────────────────────────┘
```

**Beskrivelse:**
- **Plassering:** Flytende nederst over bunnnavigasjon eller kamera.
- **Tekst:** Produktnavn, mengde og måltid, med local-first-status.
- **Handling:** [Angre] sletter den konkrete siste registreringen lokalt og køer sletting for synk.
- **Lukk:** Meldingen kan dras ned og slippes for å lukkes før timeren utløper. Et kort drag under terskelen fjærer tilbake.
- **Skanning:** Kameraet fortsetter automatisk med mengde reset til 100 g.
- **Timing:** Auto-dismiss etter 4 sekunder hvis brukeren ikke gjør noe.
- **Tilgjengelighet:** Hele teksten kan brytes ved stor skrift; Angre har minst 44 × 44 pt trykkflate. VoiceOver forlenger visningen til 8 sekunder og tilbyr handlingen «Lukk bekreftelse». Redusert bevegelse fjerner overgangs- og returanimasjonen.

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

## 3.3 Navigasjon og førstegangsbruk – kontrollert mot kode 2026-10-04

```text
App-rot: sesjonsgjenoppretting
├─ Ny lokal profil → Første måltid
│  ├─ Søk / Skann / Manuelt → produktkort → lokal logging → Hjem med Angre
│  ├─ Gå til Hjem → Hjem
│  └─ Logg inn → valgfri kontoflyt
├─ Kjent konto med mislykket gjenoppretting → eksplisitt innlogging
└─ Fullført førstegangsbruk → vedvarende bunnmeny
   ├─ Hjem → valgt måltid eller hele dagsloggen
   ├─ Søk → produktkort
   ├─ Loggfør → loggingark med valgt dato og måltid
   ├─ Utvikling → energi, makroer og vektregistrering
   └─ Profil → daglige mål, personlige detaljer og valgfri konto
```

Loggfør er en vedvarende handling som åpner et ark. Lokal bruk krever ingen
konto eller målveiviser. Førstegangsvisningen heter «Første måltid» og har
«Gå til Hjem» og «Logg inn» i navigasjonslinjen. Ved stor tekst stables
søkehandlingene, og innholdet kan rulles. Den eldre målveiviseren er bevart i
kode uten aktiv inngang i denne flyten.

---

## 3.4 Modal & Sheet Presentasjon

| Situation | Presentation | Dismiss |
|-----------|--------------|---------|
| Kamera-skanning | Full screen | Avbryt-knapp, back gesture |
| Loggbekreftelse | Kompakt, ikke-modal melding | Auto-dismiss (4s), dra ned eller Angre |
| Søk manuelt | Sheet (half-screen) | Back / Avbryt |
| Historikk-panel | Sheet (70% height) | ✕ eller back gesture |
| "Ikke funnet" | Alert / Sheet | "Ja" / "Nei" |
| Favoritt-share | Action sheet (iOS) | Valg eller Avbryt |
| Slett enkeltvare | Kompakt melding med Angre | 4s (8s VoiceOver), dra ned eller Angre |

## Demokontroller i utviklingsversjonen

DEBUG-versjonen har demokontroller bare i Profil, uten en vedvarende demorad
over skjermene. Profil har «Demomodus» og
«Tilbakestill demodata». Tilbakestilling bekreftes med en forklaring om at
endringer i demoen fjernes og vanlige data beholdes. Under klargjøring vises
fremdrift og interaksjoner deaktiveres; feil beholder tidligere appkontekst.
Bytte til vanlig modus bevarer eksisterende registreringer og kontosesjon.

### Måltidsrom (gjeldende loggvisning)

Dato → Hele dagen, antall og dagsnæring → fire
måltidsseksjoner med produktbilder, matnavn, mengder og Legg til.
Måltidsoverskriftene følger innholdet ved scrolling og festes ikke under toppmenyen.
Ingen måltidssnarveier eller måltidsfiltrering. Tomme måltider har
Legg til. Skjermhodet har én •••-meny for gjenbruk og dagsvalg; dagsloggen har ikke søk.
Se design-and-user-flow.md for handlinger og tilstander.

### Navigasjonstillegg 2026-10-02

Ved måltidsoverskriften på Hjem står «Se dagslogg»; synlige varerader åpner
redigering. Midtknappen er merket «Loggfør». Alle Legg til-innganger bruker
samme ark med søk, skann, Registrer manuelt, måltid/dato og en todelt velger
for «Nylig logget» / «Lagrede måltider». Bare valgt liste vises; øvrige
favoritter og nylig brukt er tilgjengelige i Søk. Arket stabler måltidsvalg ved tilgjengelighetsstørrelser.
I «Nylig logget» vises «Loggfør [mengde]» som en knapp i kortets bredde,
med avrundet, diskret ramme, svak merkevarebakgrunn og minst 44 punkters trykkflate.
Listen starter direkte under velgeren uten å gjenta «Nylig logget» som overskrift.
Hjems næringsfelt viser registrert energi uten mål når visningsvalget er på.
Dagsloggen har en •••-meny for gjenbruk og dagsvalg; måltidsmaler har en 44-punkters
menyknapp for redigering og sletting. Eksisterende komponenter og tokens gjenbrukes.

### Produktkort: antall og porsjoner (2026-10-02)

Mengdekortet har en meny for gram/ml og dokumenterte porsjoner. Enhetsvelgeren
viser bare navnet på valgt enhet eller porsjon. Antall har −/+ på egen rad,
bare ved porsjonsvalg. Totalen vises for porsjoner; gram/ml gjentas ikke under
mengdefeltet. Porsjonsstørrelse og kilde åpnes via en infoknapp ved totalen.
Loggredigering åpnes i stor sheet ved stor tekst for
å beholde en brukbar rulleflate. Historiske logger åpner sitt lagrede grunnlag.

### Loggfør-arkets rulleflate (2026-10-04)

Innholdet holdes innenfor arkets tilgjengelige bredde også når «Lagrede
måltider» velges. Lange måltidsnavn brytes vertikalt. Rulleflaten er vertikal;
elastisk sprett brukes bare når innholdet overstiger tilgjengelig størrelse,
slik at korte lister ikke kan dras elastisk sideveis.


### Første logging – kompakt hierarki (2026-10-05)

Navigasjonslinjen viser «MatLogg», «Hjem» (VoiceOver: «Gå til Hjem») og
«Logg inn». Før søk vises full overskrift «Logg din første matvare» og en
kort instruksjon over søkekontrollene. Lokal lagring, datatap, eksport og
personvern samles i én dempet informasjonsflate under kontrollene. Den
dupliserte tomtilstandsbeskjeden skjules ved første logging. Ved søk skjules
introduksjon og lagringsinformasjon slik at treff får plass.
