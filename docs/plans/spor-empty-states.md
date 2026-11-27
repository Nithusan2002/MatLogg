# Spor i flere tomtilstander

Implementeringsplan, 26. november 2026. Første kodeleveranse er implementert;
se kontrollstatus nederst.
Arbeidsbranch: `codex/spor-mascot-iphone-preview`, oppdatert med
`origin/main` ved `dd38922` gjennom merge `3668059`.

## Mål og avgrensning

Gi brukeren en vennlig forklaring og en tydelig vei videre når dagsloggen
eller skannehistorikken faktisk er tom. Gjenbruk `SporIllustration` som
dekorativt stillbilde, eksisterende typografi, farger og knapper. Ingen ny
3D-scene, pust, trykkhilsen, lasting av ressurser eller domenelogikk i disse
tomtilstandene. Eksisterende Hjem-maskot, favoritter og lagrede måltider beholdes.

Første leveranse omfatter dagslogg og skannehistorikk. Tom hurtiglogg og ingen
søketreff vurderes senere, etter visuell kontroll av de to første plasseringene.
Feiltilstander, manglende helsetilgang og manglende vektdata får ikke maskot.

## Leveranser og rekkefølge

| Prioritet | Plassering | Illustrasjon | Neste steg |
| --- | --- | --- | --- |
| 1 | Tom dagslogg på Hjem | Gjenbruk figuren ved hilsenen | «Legg til mat» |
| 1 | Tom skannehistorikk | Stillfigur, start med 120 pt | «Skann strekkode» |
| 2 | Ingen nylig loggede matvarer | Eventuelt 64–80 pt hvis plassen tillater det | Behold søket synlig og tilgjengelig |
| 3 | Ingen søketreff | Eventuelt liten stillfigur | Behold søk, skanning og manuell registrering |

Størrelsene er utgangspunkt for visuell kontroll, ikke nye globale tokens.
Fullfør og kontroller prioritet 1 før de to andre vurderes. Eksisterende
animasjoner endres ikke av denne leveransen.

## 1. Bekreft tilstand og handling før visuell endring

- Gjennomgå den oppdaterte lese-/feilkontrakten fra `main`. Spor vises bare
  etter vellykket lasting med null resultater, aldri under første lasting
  eller ved SQL-/dekodingsfeil. Behold feiltekst, retry og kontekstvern.
- Dagsloggen: kontroller `HomeView` og `HomeOverviewViewModel`, inkludert
  valgt dato og eventuell beholdt oversikt ved refresh-feil. En tom filtrert
  liste må ikke beskrives som en helt tom dag.
- Skannehistorikken: behold vilkåret `scans.isEmpty && !isLoading &&
  errorMessage == nil` i `ScanHistoryView` i `HomeView.swift`.
- Bekreft eksisterende vei til matlogging og skanning. Gjenbruk handlingene;
  ikke opprett en parallell navigasjonsflyt. Skann-knappen kan bruke den
  eksisterende `showScanCamera`-presentasjonen.

## 2. Tom dagslogg – faktisk navigasjon

Kodegjennomgangen under implementering viste at den separate `LoggView` ikke
opprettes av dagens app. Dagsloggen brukeren ser, ligger i `HomeView.swift`.
Der beholdes Spor ved hilsenen; ingen ekstra illustrasjon legges i tomtilstanden.
Den eksisterende tomteksten endres til «Ingen mat registrert denne dagen»,
og den eksisterende knappen får teksten «Legg til mat». Samme
`onOpenQuickLog`-handling gjenbrukes og valgt dato beholdes.

`HomeOverviewViewModel.shouldShowEmptyDay` beholder ansvaret for å skille
vellykket tom dag fra lasting, feil og feil profil/dato. Ingen endring i
leselogikk eller nye ViewModels. Den inaktive `LoggView` beholdes uendret;
planen innfører ingen ny navigasjonsvei til den.

## 3. Tom skannehistorikk

`ScanHistoryView` finnes i koden, men åpnes ikke av dagens navigasjon.
Tomtilstanden er forberedt i denne visningen; ingen ny inngang legges til
uten valg av plassering. Den kan derfor ikke kontrolleres gjennom vanlig
navigasjon i appen ennå.

Bytt den eksisterende enkle tomteksten i `ScanHistoryView` til en kompakt,
vertikal gruppe med stillfigur, tittel, forklaring og knapp:

- Tittel: «Ingen nylige skanninger».
- Forklaring: «Matvarer du skanner, dukker opp her.»
- Knapp: «Skann strekkode», koblet til eksisterende kameraflyt.

Visningen er et sheet med medium høyde. Innholdet må kunne rulle ved store
tekststørrelser; knappen skal være tilgjengelig uten å øke sheetet til en ny
fullskjermsflyt. Behold lukking, loggkvittering og eksisterende kamera-/søkflyt.

Kontroller overgangen fra historikksheet til kamera, kameratillatelse,
avbryt og retur. Løs eventuelle presentasjonskollisjoner i eksisterende
navigasjonsstruktur fremfor å opprette en ekstra kamerainstans.

## Senere vurdering: hurtiglogging og søketreff

### Ingen nylig loggede matvarer

Berørt område: `recentContent` i `MatLogg/Views/Home/QuickLogSheet.swift`.
Behold skillet mellom første lasting, lesefeil med retry og en vellykket tom
liste. Prøv en liten illustrasjon sammen med «Ingen nylig loggede matvarer»
og «Her finner du matvarer du har logget tidligere.»

Vurder skjermen med tastatur, liten høyde og største tekststørrelse.
Utelat figuren dersom søk eller hovedhandlingen skyves ut av syne. Ingen
egen maskotknapp eller ekstra handling er nødvendig her.

### Ingen søketreff

Berørt område: resultatseksjonen i `MatLogg/Views/Home/FoodSearchView.swift`.
Skillet mellom «Ingen lokale treff» og ferdig søk skal beholdes. Ikke vis
«Ingen treff» mens søket pågår, ved feil eller før brukeren har søkt.
Lokale nulltreff må fortsatt tilby eksisterende globalt søk der det finnes.

Ved ferdig søk kan teksten være «Ingen treff på «[søketekst]».» og
«Prøv et annet navn eller skann strekkoden.» Behold også eksisterende vei
til manuell registrering. En eventuell illustrasjon må ikke flytte
søkehandlingen eller gjøre raske endringer av søkeord visuelt urolige.
Kontroller lange søkeord, tømming av feltet og tastatur før dette tas inn.

## 4. Kontroll og ferdigkriterier

- Én dekorativ maskot per skjerm, uten egen VoiceOver-stopp eller trykkhandling.
  Leserekkefølge: tittel, forklaring, relevant knapp. Minst 44 pt trykkflate.
- Inspiser lys/mørk modus, liten skjerm og største Dynamic Type. Ingen
  avkuttet tekst, utilgjengelige knapper eller innhold bak bunnmenyen.
- Kontroller tom dagslogg, annen dato, tomt filter, logg med innhold,
  tom skannehistorikk og historikk med innhold. Figurene skal forsvinne
  når første registrering eller skanning blir tilgjengelig.
- Kontroller at «Legg til mat» faktisk åpner eksisterende loggføringsflyt
  for valgt dato, og at «Skann strekkode» åpner kameraet og kan avbrytes.
  Når listen blir tom etter sletting, skal riktig tomtilstand komme tilbake.
- Kjør relevante eksisterende lese-/feiltester. Kontroller første lesefeil,
  refresh-feil og vellykket retry; feil må aldri bli forklart som tom historikk.
- Kjør målrettede UI-scenarioer i disponibel QA-app. Manuell VoiceOver og
  kameraåpning kontrolleres separat. Oppgi eksplisitt hvis fysisk QA er blokkert.
- Gjennomgå diffen mot arkitekturprinsippene. Ingen endring i lagring,
  eierskap, synkkontrakt eller backend er forventet. Oppdater den eksisterende
  maskotseksjonen i designsystem-/flytdokumentasjonen etter implementering.

Den separate 3D-overgangen og pusten på Hjem er kontrollert fysisk
27. november i lys/mørk modus og med relevante bevegelsesinnstillinger.
Energimåling gjenstår før PR; se testveiledningen.

## Berørte filer og gjennomføring

Første kodeleveranse endrer `HomeView.swift`, med gjenbruk av
`DesignSystem/Components/SporIllustration.swift`. `LoggView.swift` endres ikke. Hold
presentasjonen lokalt i de to skjermene; trekk bare ut en liten felles visuell
komponent hvis implementasjonen faktisk blir lik. Ingen ny ViewModel,
repository, nettverksforespørsel eller innsamling av data er forventet.

Utvid relevante eksisterende UI-tester med tom, feil og fylt tilstand samt
de to hovedhandlingene. Bruk eksisterende syntetiske QA-fixturer. Nye rene
logikktester er bare nødvendig hvis implementeringen innfører ny logikk;
eksisterende lese-/retrytester skal fortsatt dekke feilkontrakten.

Arbeidsrekkefølge: dagslogg → skannehistorikk → målrettet QA → visuell
vurdering av de to valgfrie plasseringene. Etter første leveranse oppdateres
eksisterende design-/flytdokumentasjon og verifiseringsstatus. Eventuell
commit skal avgrenses til dette arbeidet; øvrig lokalt arbeid bevares.

## Kontrollstatus for første kodeleveranse

- Dagslogg: eksisterende figur ved hilsenen og eksisterende handling beholdes.
- Skannehistorikk: dekorativ stillfigur, skanneknapp og rullbart innhold er
  klargjort, men mangler fortsatt inngang i produktets navigasjon.
- iPhone 17, iOS 27.3: UI-test for dagslogg med største tekststørrelse,
  tidligere dato og åpning/lukking av logging bestod. Skjermbildet er inspisert.
- Tre `HomeOverviewViewModelTests` og to målrettede `LoadingStateTests`
  bestod på samme isolerte QA-app. De dekker dato/profil, første/siste logg,
  loading/feil/reset, refresh og sen skannehistorikkrespons.
- Simulator-testbygg og isolert iPhone-testbygg kompilerte. Siste justering
  med ny lasting ved kameralukking er kontrollert ved kompilering.
- Skannehistorikkens faktiske layout og kameraflyt, mørk modus og manuell
  VoiceOver er ikke kontrollert i denne leveransen.
- Ingen implementering av de to lavere prioriterte plasseringene.
