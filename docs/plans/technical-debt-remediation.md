# Utbedringsplan for teknisk gjeld

**Gjeldende arbeid:** Runde 2 er startet etter brukerens nye beskjed
25. november. Resultater føres når kontrollene er fullført.

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
| 1. Lesefeil | Throwing `loadAllLogs`/`loadLogs` sjekker prepare, step og dekoding. Dagsoversikt bruker throwing `loadSummaries`; eksport, gjenbruk, kopiering og angre stopper ved lesefeil. Oppdateringsfeil beholder samme brukers/dags innhold; bruker-/datobytte nullstiller. Måltidsrommet viser feil og retry. | iOS-regresjonene er grønne på fysisk enhet; manuell VoiceOver og visuell feil/retry gjenstår. Eldre ikke-kastende API-er er beholdt for kompatibilitet og er fortsatt gjeld; nye produksjonskall skal bruke throwing-metodene. |
| 2. Kandidatbevis | Én navngitt kodecommit, målrettede resultater og åpne porter er samlet i produksjonsberedskap. Delt `MatLogg`-scheme er lagt til for rene checkouts og CI. | 41 enhetstester og tre UI-tester er grønne på fysisk iPhone. Øvrige releaseporter står åpne. Ingen produksjonsgodkjenning. |
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

### Fysisk verifisering gjennomført

25. november bestod kodekandidat `b9b8eb7` 41 målrettede tester i fem suiter
og tre UI-tester på iPhone 17 / iOS 27.3, i separat QA-app. Dette lukker det
opprinnelige hullet for iOS-runtime i de berørte suitene. UI dekker kamera-
inngang/manuell strekkode, største tekst og måltidsredigering med omstart.
Skjermbilder er gjennomgått. Manuell VoiceOver, faktisk kameradeteksjon og
visuell feil/retry står fortsatt åpne. Resultater og avgrensning finnes i
`docs/testing.md`. Go for lokal sammenslåing av tiltaket; ingen releasegodkjenning.

## Runde 2 – fullføre de fire gjenværende punktene

**Status: startet etter brukerens beskjed «Start runde 2».** Grunnlag: lokal `main` `14e861a`.
Arbeidsbranch `codex/technical-debt-followup` er opprettet fra denne committen.
Planen ble først skrevet uten implementering. Gjennomføringen er nå startet.
Tidligere resultater over gjelder runde 1.

Målet er å fjerne feilskjulende kompatibilitet, få konsistent feilhåndtering i
berørte lokale dataflyter, avgrense LocalStore sitt ansvar og gjøre legacy-
backendens videre levetid til et konkret, etterprøvbart valg.

### 1. Fjern gamle historikkgrensesnitt — først

**Berørte områder:** FoodLogRepository, SavedMealRepository, DatabaseService,
LocalStore, berørte kallere og testdobler. Anslag: 1–2 arbeidsdager.

- Behold én feilformidlende vei for all historikk, perioder, oppsummeringer
  og lagrede måltider. Avvikle ikke-kastende `getAllLogs`, `getLogs`,
  `getSummary`, `getTodaysSummary` og `getSavedMeals` i produksjonsgrensesnittene.
- Fjern standardimplementasjoner som lar en throwing-metode falle tilbake
  til en ikke-kastende lesing. Avledede standardmetoder kan beholdes når
  de bruker feilformidlende kilder og lar feilen gå videre.
- Avstem alle kallere og testdobler med kontrakten. Happy-path-tester kan
  bli throwing; ikke erstatt forventede feil med `try?`, `try!` eller tomme
  resultater for å få kompileringen grønn.
- Bevar forskjellen mellom gyldig tomt resultat, manglende valgfri rad og
  mislykket lesing. Et manglende forventet oppsummeringsresultat er en feil,
  ikke et nytt nullinntak.

**Ferdig når:** søk i produksjonskoden ikke finner de gamle grensesnittene
eller kompatibilitetsfallbackene; berørte kallere kompilerer og testene viser
at feil går hele veien fra LocalStore til repository og ViewModel/eksport.

**Verifisering:** HistoryReadFailureTests, HistoryReadViewModelTests,
MealReuseTests, RenderPresentationTests, SavedMealsTests og relevante
lagrings-/eksporttester. Kjør bare de suitene endringen faktisk berører.

### 2. Utbedre øvrig feilskjuling i berørte lokale dataflyter

**Berørte områder:** repository-kontrakter, DatabaseService, LocalStore,
eksport, søk/matching, favoritter, mål/vekt og berørte ViewModels.
Anslag: 3–6 arbeidsdager, delt i små endringer etter dataområde.

Før implementering lages en kort, avgrenset oversikt over de aktuelle
metodene og deres kallere. Følgende funn er allerede bekreftet i kode:

| Område | Problem og ønsket resultat |
| --- | --- |
| Mål og vekt | `getLatestGoal`/`latestGoal` og `getWeightEntries` kan skjule SQL-/dekodingsfeil som ingen mål eller tom vekthistorikk. Innfør feilformidlende kontrakter og bevar sist lastede data for samme profil. |
| Lagrede måltider | `loadSavedMeals` sjekker SQL-feil, men hopper over rader som ikke kan dekodes. Avvis lesingen som ufullstendig framfor å presentere en redusert samling som komplett. |
| Produkter og favoritter | Gå gjennom enkelt-/batchoppslag, strekkodeoppslag, favorittstatus, favorittliste og nylige produkter. Skille fravær fra lagerfeil; et batchoppslag skal ikke gi et tilsynelatende vellykket delresultat ved SQL-/dekodingsfeil. |
| Skannehistorikk og matching | Kontroller prepare, bind, step og dekoding. Bevar eksisterende resultater ved oppdateringsfeil. En brukerbekreftet matching skal ikke forsvinne eller erstattes på grunn av en skjult lesefeil. |
| Eksport | Samle alle feilrelevante kilder gjennom throwing-grenser: matlogger, lagrede måltider, mål, vekt, favoritter og øvrige eksporterte opplysninger. Ikke opprett en tilsynelatende komplett eksport når en nødvendig kilde feiler. |
| Personlige detaljer | Vurder de berørte `PersonalDetailsStore.load`-/migreringskallene, som kan gi `.empty` ved dekodingsfeil. Bevar kildedata og skill «ikke utfylt» fra «kunne ikke leses». Ingen ny gjetting av målgrunnlag. |
| Gjenoppbyggbar katalogcache | Best-effort er bare tillatt når en uttrykkelig, testet fallback finnes, for eksempel den medfølgende Matvaretabellen. Ikke overfør denne policyen til brukerdata. Dokumenter fravær, utløp og feil som separate interne utfall. |

Arbeidsmåte per dataområde:

1. Skriv en regresjon for faktisk feilskjuling, og bekreft feil før retting.
2. Gjør SQLite-resultatene og kontrakten eksplisitte; unngå rå SQL-feil eller
   personinnhold i brukerrettet tekst/diagnostikk.
3. La ViewModel eie loading/feil/retry. Oppdateringsfeil beholder samme
   konteksts data; profil-/datobytte fjerner gamle data. Utdaterte asynkrone
   svar skal ikke publisere innhold eller feil i en nyere kontekst.
4. Bevar data ved feil. Ingen automatisk reset, sletting av korrupte rader
   eller ny ernæringsverdi som erstatning for det som ikke kunne leses.

**Ferdig når:** de navngitte dataflytene enten formidler feil eller har en
konkret, testet cachefallback. Ingen nødvendig eksportkilde skjuler feil;
tester dekker tomt lager, manglende rad, SQL-feil, korrupt rad, retry og
profilbytte der dette er relevant. Eventuelle funn utenfor omfanget føres
eksplisitt videre; de regnes ikke som løst av denne runden.

**Verifisering:** nye feiltester ved SQLite-/repositorygrensen og målrettede
eksisterende tester for HealthProfile, ProfileExport, SavedMeals, Barcode,
FoodSearch, favoritter og personlige detaljer, etter faktisk berørt kode.
Bruk disponibel lokal database og separat QA-app. Ingen ekte Helse-data trengs.

### 3. Del LocalStore etter ansvar uten å splitte transaksjoner

**Avhengighet:** punkt 1 og de aktuelle delene av punkt 2 skal være grønne
før kode flyttes. Anslag: 2–4 arbeidsdager for en første sammenhengende oppdeling.

- Skill ut kontrollert lesing og relevante domeneområder, eksempelvis
  historikk, produkter og mål/vekt, i små filer med tydelig ansvar.
- Samle duplisert håndtering av statements, bindings, stepping og dekoding
  når det gir en enklere, testbar feilgrense. Gjenbruk eksisterende mekanismer
  framfor å innføre et generelt persistensrammeverk.
- LocalStore beholder eierskapet til tilkobling, seriell kø, migrasjoner og
  transaksjoner. Ikke gjør databasepekeren eller transaksjonsmekanismen bredt
  tilgjengelig bare for å få filoppdelingen til å kompilere.
- Domeneendring, synkhendelse og eventuell Helse-outbox skal fortsatt være
  i samme eksisterende transaksjon. Ingen ny database, skjemaendring,
  kømodell eller actor-modell inngår i en ren filoppdeling.
- Hold feilretting og mekanisk flytting i separate, reviewbare endringer,
  slik at atferdsendringene kan vurderes uavhengig av flyttingen.

**Ferdig når:** ansvarsområdene er tydelige og transaksjons-/IO-grensene er
bevart. Linjetall alene er ikke et ferdigkriterium. Gjennomgå spesielt
deadlock/reentrancy, statement-opprydding og feil under rollback.

**Verifisering:** berørte lagringstester, migrerings-/gjenåpningstester og
atomisitetsregresjoner for domene + synkkø + Helse-outbox. En flytting alene
skal ikke kreve nye ernærings- eller datakontrakter.

### 4. Avklar legacy-backendens levetid og vedlikeholdsgrense

**Omfang:** backend/README, relevante CI-/deployreferanser, appens transport-
avhengigheter og beslutningsloggen. Anslag: 1–2 arbeidsdager for en konkret
beslutningspakke; selve avviklingen estimeres etter valgt omfang.

- Fastslå hvilke legacy-avhengigheter som bare finnes i kildekode/test/CI,
  og hvilke som eventuelt fortsatt brukes av distribuerte klienter eller
  drift. Ukjent faktisk drift skal føres som ukjent, ikke som ingen bruk.
- Dokumenter aktive delte typer i APIService/SupabaseService/SyncEngine og
  en trygg flytterekkefølge før gamle klientmetoder kan fjernes. Produktkatalog
  og lokal AuthService skal ikke feilaktig tas med som gammel serverkode.
- Konkretiser behold-alternativet: sikkerhet, nødvendige avhengighetsoppdateringer
  og eksisterende tester; ny serverfunksjonalitet hører til Supabase. Ikke
  skru av CI eller svekk eksisterende porter som del av oppryddingen.
- Lever et avviklingsalternativ med eksakt filliste, CI-/deployendringer,
  bevaring av relevante tester, arkivpunkt og gjenopprettingsmåte.
- Avstem opprinnelige cutoverkrav med lokal lansering. Backup-/skykrav skal
  ikke fjernes eller anses oppfylt uten en eksplisitt beslutning.

**Ferdig når:** gjeldende vedlikeholdsgrense og hvert avviklingsvilkår har
status, dokumentert bevis eller konkret manglende avklaring. Brukeren får et
ferdig beslutningsgrunnlag før eventuell kode-/driftsavvikling godkjennes.
Det er ikke et ferdigkriterium at backend-mappen nødvendigvis slettes.

**Stoppgrense:** ingen større legacy-sletting, tilgangsendring eller endring
av produksjonsdrift uten egen avklaring, jf. prosjektets «Stopp før» og
backend/README. En slik avklaring gjelder den konkrete avviklingspakken,
ikke tillatelse til rutinemessige lokale rettelser.

### Rekkefølge, kvalitetsporter og estimat

1. Punkt 1: én canonical feilformidlende kontrakt.
2. Punkt 2: små feilrettinger per dataområde, med regresjoner før retting.
3. Punkt 3: mekanisk oppdeling etter at de berørte feilbanene er grønne.
4. Punkt 4: ferdigstill beslutningspakken; behold-policy gjelder inntil annet
   er avklart. Dette analysearbeidet kan gjøres uavhengig av kodeendringene.
5. Egenreview mot architecture-principles: avhengighetsretning, local-first,
   atomiske transaksjoner, eierskap, kilde/enhet og testbare IO-grenser.
6. Kjør berørte suiter på QA-iPhone. Bruk tidligere autorisert separate
   QA-identitet og syntetiske data; telefonen må være tilkoblet og ulåst.
   Full suite kjøres bare ved konkret behov fra endringen eller CI-porten.
7. Knytt resultatene til ny kodecommit og oppdater eksisterende kandidatoversikt.
   Ny kontrakt/refaktorering trenger egne bevis; runde 1-resultater gjenbrukes
   ikke som om de verifiserer ny kode.

Samlet grovestimat: **7–14 arbeidsdager**, uten venting på enhet, eksterne
driftsopplysninger eller avviklingsbeslutning. Estimatet strammes inn etter
kallergjennomgangen i punkt 1–2. Ingen produksjonsutrulling eller synkaktivering
inngår. Manuell VoiceOver, faktisk kameradeteksjon og visuell feil/retry fra
første runde beholdes som egne åpne kontroller.

**Skills ved gjennomføring:** offline-sync → backend-api → ios-swiftui og
nutrition-privacy, deretter qa-release. Product-design leses før eventuell
endret feiltekst eller retry-presentasjon. Product-review kreves hvis arbeidet
avdekker behov for endret produktscope; det tas ikke inn som skjult refaktorering.

**Gjennomføring er autorisert; særskilte stoppgrenser for avvikling og produksjon gjelder fortsatt.**
