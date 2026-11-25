# Utbedringsplan for teknisk gjeld

Dato: 25. november 2026. Status: første gjennomføring ferdig; åpne porter er spesifisert nedenfor.
Grunnlag: statisk gjennomgang av lokal `main`, commit `85755ea` fra 21. november.
`origin/main` pekte på samme commit ved kontroll, men ble ikke hentet på nytt.
Arbeidskopiens parallelle endringer inngår ikke i vurderingen.

## Mål og avgrensning

Reduser risiko for misvisende historikk, gjør releasebevis etterprøvbare og
senk kostnaden ved videre endringer. Første lansering forblir local-first.
Planen åpner ikke for synk, endret autentisering, produksjonsutrulling eller
sletting av legacy-kode. Slike handlinger krever separat avklaring.

Store filer er vedlikeholdsindikatorer, ikke dokumenterte feil i seg selv.
Åpne kontroller i eldre dokumentasjon må kontrolleres mot valgt kandidat før
de regnes som fortsatt åpne. Estimatene under er grove arbeidsdager for én
utvikler, eksklusive venting på eksterne avklaringer.

## 1. Skill databasefeil fra tom historikk — høy prioritet

**Omfang:** `MatLogg/Services/LocalStore.swift`, `DatabaseService.swift`,
berørte repository-protokoller, ViewModels og tester. Anslag: 2–4 dager.

- Start med `getAllLogs` og `getLogs`: de sjekker ikke returverdier fra
  SQL-forberedelse eller om iterasjonen avsluttes med `SQLITE_DONE`.
- Lag en reproduksjon med disponibel SQLite-database der lesing feiler.
  Vis at dagens kode kan returnere et tomt eller ufullstendig resultat.
- Innfør kontrollert feilformidling gjennom repository til ViewModel.
  Tomt resultat er en gyldig tilstand bare ved vellykket lesing uten treff.
- Kontroller tilsvarende mønster i direkte berørte oppsummerings- og
  historikklesinger. Gjør eventuelle øvrige funn til en avgrenset oppfølging.
- Ved oppdateringsfeil: behold tidligere lastet historikk og vis feilstatus.
  Ved førstegangsfeil: vis feiltilstand med nytt forsøk, uten falske nullverdier.
  Diagnostikk skal ikke inneholde matlogger eller andre persondata.

**Ferdig når:** regresjonen feiler før retting og består etterpå; tom database,
SQL-feil og mislykket oppdatering gir ulike, forventede tilstander. Eksisterende
logging og domene-/eventtransaksjoner er bevart.

**Minste verifisering:** nye lagringstester og tester for berørte ViewModels.
Kjør eksisterende relevante tester for logging, måltidssummer og batchlagring
når disse kallene berøres. Bruk syntetiske data og separat QA-lager.

**Skills ved implementering:** offline-sync → ios-swiftui; nutrition-privacy
for visning av ernæringssummer. Backend-api hvis kontrakt faktisk berøres.

## 2. Knytt releasebevis til én kandidat — før neste release

**Omfang:** `docs/current-state.md`, `docs/production-readiness.md`,
`docs/testing.md` og eksisterende CI. Anslag: 1–2 dager pluss manuell QA.

- Velg kandidatcommit og registrer commit, byggtype, enhet/OS, dato og
  resultatlenke for relevante kontroller.
- Lag én kort oversikt over kandidatens porter: bestått, åpen eller ikke
  relevant. Skill krav for lokal lansering fra framtidig skyfunksjon.
- Avstem eldre resultater og åpne punkter mot kandidaten. Historiske grønne
  kjøringer er ikke bevis for senere endret kode.
- Avklar faktisk status for VoiceOver, kamera, Apple-innlogging og
  Release/TestFlight. Kjør manglende kandidatkontroller proporsjonalt med risiko.
- Beskriv fortsatt at JSON-eksport ikke kan importeres. En eventuell import-
  eller backupfunksjon krever eget produktscope; den bygges ikke som opprydding.

**Ferdig når:** alle relevante porter har kandidatbundet bevis eller en
eksplisitt blokkering. Release får en separat go/no-go; dokumentrydding alene
gir ingen releasegodkjenning.

**Minste verifisering:** dokumentkontroll og eksisterende CI for kandidaten;
bare manglende eller berørte manuelle flyter testes på nytt. Rå resultater
holdes utenfor repoet, med korte referanser i dokumentasjonen.

**Skills:** qa-release, supplert med relevante fag-skills for de faktiske kontrollene.

## 3. Reduser kobling i de største filene — gradvis

**Omfang:** først `HomeView.swift` og `LocalStore.swift`; deretter vurderes
`APIService.swift` og `Models.swift`. Første avgrensede del: 2–4 dager.

- Velg én sammenhengende del med hyppige endringer eller konkret testproblem.
  HomeView har 2427 linjer og LocalStore 2545 i vurdert commit.
- Flytt rene visuelle deler til komponenter med smale verdi-inputs og callbacks.
  Feature-state og handlinger skal fortsatt eies av ViewModels.
- Del lokal persistens etter ansvar bare der dette gir tydeligere grenser.
  Behold én koordinert SQLite-/transaksjonsmekanisme; en filoppdeling skal ikke
  splitte atomisk domeneskriving og synkhendelse.
- Bevar offentlig adferd og eksisterende protokoller når mulig. Ikke innfør
  nye lag eller et generelt rammeverk for å redusere linjetall.
- Vurder singleton-avhengigheter bare i den delen som faktisk berøres.
  Foretrekk injeksjon ved IO-grensene.

**Ferdig når:** valgt ansvar har en tydelig eier, UI har ingen ny IO eller
domenelogikk, og berørte tester består uten svekkede assertions. Ingen
linjetallsgrense er et selvstendig ferdigkriterium.

**Minste verifisering:** eksisterende tester for flyten; ved ren visuell
uttrekking målrettet kompilering og én relevant UI-smoke. Ved lagringsendring
testes rollback og atomisk domene-/eventskriving.

**Skills:** ios-swiftui; offline-sync ved lagringsendringer. Product-design
hvis synlig layout eller brukerflyt endres.

## 4. Avklar levetiden til legacy-backend — beslutning før opprydding

**Omfang:** `backend/`, aktive klientreferanser, CI og eksisterende cutover-
dokumentasjon. Beslutningsgrunnlag: 0,5–1 dag. Avvikling estimeres separat.

- Bekreft gjenværende runtime-, deploy-, test- og driftsavhengigheter til
  NestJS/Prisma. At appens aktive transport er Supabase beviser ikke at alt
  legacy-innhold er overflødig.
- Foreslå konkrete avviklingskriterier og avstem dem mot tidligere krav om
  cutover/pilot. Avklar om disse fortsatt gjelder med lokal lansering.
- Hvis backend beholdes: gi den avgrenset vedlikeholdsscope og unngå å utvide
  begge plattformer for nye, ikke-avtalte funksjoner.
- Hvis avvikling velges: beskriv arkivering, avhengigheter og verifisering,
  og be om godkjenning før vesentlig kode slettes eller tilgang endres.

**Ferdig når:** en godkjent beslutning i `docs/decisions.md` sier hvorfor den
beholdes, eller hvilke kriterier som åpner for en separat avviklingsendring.

**Minste verifisering:** referansesøk og kontroll av CI/deploykonfigurasjon.
Ingen produksjonsendring eller databaseoperasjon inngår.

**Skills:** backend-api og offline-sync.

## Gjennomføring og sluttkontroll

Start med tiltak 1. Gjør kandidatoversikten i tiltak 2 før neste release.
Tiltak 3 tas i små, separate endringer når berørte områder videreutvikles.
Beslutningsgrunnlaget i tiltak 4 kan utarbeides uavhengig; sletting venter på
egen godkjenning. Første innsats bør dermed være omtrent 3–6 arbeidsdager
for databasefeil og kandidatoversikt, med manuell QA i tillegg.

For hver implementeringsendring:

1. Bekreft fersk `main` og isoler endringen fra parallelle arbeidsendringer.
2. Definer ønsket adferd og minste relevante kontroll før redigering.
3. Kjør målrettede tester med `-only-testing` etter oppskriften i
   `docs/testing.md`; full pakke krever en konkret begrunnelse.
4. Kontroller egen diff mot `docs/architecture-principles.md`: avhengighetsretning,
   local-first, transaksjoner, eierskap og testbarhet. `localOnly` beholdes.
5. Rapporter utførte kontroller og gjenværende hull. Stopp ved uavklarte
   arkitekturavvik, destruktive tiltak eller endret avtalt scope.

Planen er dokumentkontrollert mot arkitekturprinsippene og eksisterende
testoppskrift. Ingen build eller tester er kjørt for denne dokumentendringen.

## Gjennomført 25. november 2026

Kodekandidat: `b9b8eb7`, på `codex/technical-debt-remediation`, basert på `85755ea`.

| Tiltak | Resultat | Videre arbeid |
| --- | --- | --- |
| 1. Lesefeil | Throwing `loadAllLogs`/`loadLogs` sjekker prepare, step og dekoding. Dagsoversikt bruker throwing `loadSummaries`; eksport, gjenbruk, kopiering og angre stopper ved lesefeil. Oppdateringsfeil beholder samme brukers/dags innhold; bruker-/datobytte nullstiller. Måltidsrommet viser feil og retry. | Kjør iOS-regresjonene og visuell kontroll. Eldre ikke-kastende API-er er beholdt for kompatibilitet og er fortsatt gjeld; nye produksjonskall skal bruke throwing-metodene. |
| 2. Kandidatbevis | Én navngitt kodecommit, målrettede resultater og åpne porter er samlet i produksjonsberedskap. Delt `MatLogg`-scheme er lagt til for rene checkouts og CI. | Simulator-/enhetskjøring og releaseporter står åpne. Ingen produksjonsgodkjenning. |
| 3. Filansvar | Kamera, scanner-wrapper og private scannerkomponenter er flyttet samlet fra HomeView til CameraView. Kroppene er kontrollert identiske mot main. HomeView reduseres fra 2427 til 1514 linjer. | LocalStore, APIService og Models deles bare ved konkrete senere endringer/testbehov. Ingen stor refaktorering er startet. |
| 4. Legacy | Kode- og CI-avhengigheter er avklart nedenfor. Eksisterende behold-policy videreføres. | Separat godkjenning før avvikling eller større kodefjerning. |

Verifisering: 25 målrettede tester bestod i en midlertidig macOS SwiftPM-harness
med faktiske lagrings-/ViewModel-kilder (ni nye tester og 16 eksisterende
MealReuseTests). Baseline-lagring ga sju forventede feilutslag i tre tester;
normal lesing bestod også før rettelsen. Baseline brukte bare navneadaptere
for å kalle gammel implementasjon med de nye testene.
Xcode `build-for-testing` for app, unit- og UI-targeter bestod etter siste
kodeendring. Den ekstra iOS-only repository-testen er kompilert, ikke kjørt.
Ingen simulatorruntime er tilgjengelig. Se `docs/testing.md` for avgrensning
og neste målrettede iOS-kjøring. Rå logger og midlertidig harness ligger utenfor repoet.

Arkitekturkontroll: View → ViewModel → Repository → LocalStore beholdes.
Ingen endring i skjema, synkformat, lokal transaksjonsgrense eller eierskap.
Ingen IO er flyttet til views. `localOnly` og avslått synk er uendret.
Ingen nye arkitekturavvik; eldre kompatibilitetsmetoder gjenstår som eksplisitt gjeld.

### Beslutningsgrunnlag for legacy-backend

Kontrollert mot kodekandidaten:

- App-roten velger SupabaseService for konto/synk når konfigurasjon finnes,
  ellers eksplisitt utilgjengelige kontotjenester. AuthService brukes også som
  lokal profil-/nøkkelringstjeneste og kan ikke fjernes som «legacy-backend».
- APIService inneholder fortsatt gamle konto-/synkmetoder og base-URL til
  `api.matlogg.app/v1`, samtidig som tjenesten brukes aktivt til produktkatalog.
  SupabaseService og SyncEngine deler fortsatt APIService-resultat-/feiltyper.
  Å slette APIService samlet ville derfor ødelegge aktive avhengigheter.
- `backend/` har egne kilder, migrasjoner, avhengigheter og CI i
  `.github/workflows/backend-ci.yml`. Supabase-CI vedlikeholdes separat.
- `backend/README.md` krever fortsatt godkjent fysisk iPhone, staging,
  backup/restore og intern TestFlight før fjerning. Gjennomgangen bekrefter
  ikke at alle disse portene er lukket, og har ikke kontrollert faktisk drift
  av et eventuelt gammelt endepunkt.

**Gjeldende valg:** behold backend som referanse etter eksisterende beslutning.
Ny serverfunksjonalitet utvikles i Supabase. Ingen ny parallell funksjonsutvikling
eller reaktivering av gammel transport inngår i tiltaket.

**Foreslåtte kriterier for en separat avviklingsendring:**

1. Identifiser eventuelle distribuerte klienter, deployjobber og driftstjenester
   som fortsatt bruker gammel API; avklar migrering/avvikling av dem.
2. Bekreft hvilke tidligere cutoverporter som er oppfylt, og få eksplisitt
   avklaring om eventuelle skyspesifikke porter kan erstattes ved lokal lansering.
3. Bevar kontrakt-/sikkerhetstester som fortsatt har verdi for aktiv plattform,
   og flytt delte transporttyper før gamle klientmetoder fjernes.
4. Lag konkret liste over filer, workflows og driftsendringer, med arkivpunkt
   og gjenopprettingsmåte. Innhent godkjenning før sletting eller tilgangsendring.

Dette er en reviewbar avviklingsforberedelse, ikke en avviklingsgodkjenning.
