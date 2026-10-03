# Gjeldende prosjektstatus

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

Sist kontrollert mot kode: 2026-10-02.

### Loggfør igjen i hurtigmenyen – 2026-10-03

Loggfør-menyen har «Loggfør igjen» med siste faktiske mengde og enhet for
aktiv profil. Søk beholder kompakte nylige produkter som åpner produktkortet.
Valgt måltid og dato vises ved loggeknappen. Framtidige logger
utelates; endret enhet eller porsjonsgrunnlag åpner mengdekontroll.
Gjenlogging beregner næring fra lokale produktdata og lagrer ny logg og
canonical hendelse atomisk. Angre bruker eksakt logg-ID og profil.
Ingen migrasjon, synkkontraktsendring eller opplasting er innført.

Verifisert med 34 målrettede Swift-tester (`RepeatFoodTests`, `FoodSearchTests`,
`QuickLogTests`, `LogViewModelTests`) og én UI-test for direkte porsjonslogging
og Angre med største tilgjengelighetstekst på iPhone 17 Pro / iOS 26.5.
Flyttingen til hurtigmenyen er verifisert med 21 målrettede tester på tvers av
`RepeatFoodTests`, `FoodSearchTests` og `QuickLogTests`, samt UI-testen for
kompakt Søk, gjenlogging og Angre. Fysisk iPhone og manuell VoiceOver gjenstår.

Synk-/recovery-oppfølgingen 2026-10-02 inkluderer nye målrettede tester og
faktisk staging-kontroll. Øvrige resultater gjelder datoen og omfanget som er
oppgitt; se produksjonsberedskap for full avgrensning.

Dette dokumentet beskriver hva som finnes i kodebasen nå. Spesifikasjonene
under `docs/specs/` beskriver i tillegg ønsket retning og kan ligge foran
implementasjonen. Kode og versjonerte migrasjoner er teknisk sannhetskilde.

Ifølge tidligere dokumentert staging-verifisering er Supabase-cutover deployet til et eget staging-prosjekt i Stockholm-regionen:
SQL-skjema/RLS, Edge Functions, e-postbekreftelse, 15-minutters JWT,
30-dagers sletting og daglig purge-cron er konfigurert. Debug-konfigurasjonen
peker lokalt til staging, og simulatorbygg samt autentisert kill-switch-test er
grønne. `backendSyncEnabled` og serverens synk-kill-switch er fortsatt `false`.
Apple-secret/provider, eget SMTP-oppsett, backup/restore, fysisk iPhone,
TestFlight og separat produksjonsprosjekt gjenstår. NestJS/Prisma beholdes fram
til disse portene og stabil pilot er godkjent.

Oppfølging 2026-10-02: staging har vann-, porsjons- og RPC-nødstoppmigrasjonene
og sync-events v3. Siste relevante iOS-suiter gir 59 grønne tester, lokal DB
71 grønne tester, og staging-HTTP kontrollerer auth, replay, eierskap og delvis
batch. Direkte RPC respekterer nå serverens synk-kill-switch. Hosted backup,
varsler, direkte-RPC rate limiting og øvrige pilotporter gjenstår;
produksjonssynk forblir av. Se [resultatene](production-readiness.md).

Oppfølging 2026-10-03: fysisk iPhone 17/iOS 27.0 bestod 40 lagrings-/synktester
og én UI-test for lokal logging, Angre og gjenåpning, i separat QA-app.
Innlogget dashboard bekrefter at Free-planen ikke har hosted backup;
backup/PITR krever et budsjett-/scopevalg før hosted restore. Ingen
abonnement eller synkinnstillinger ble endret. Se produksjonsberedskap.

App-roten bruker `SupabaseService` for konto og synk når konfigurasjon finnes.
Uten konfigurasjon brukes eksplisitt utilgjengelige kontotjenester; lokal profil
fungerer fortsatt. NestJS er ikke appens aktive synktransport.

Debug bruker ordinær sesjonsflyt og direkte første logging som standard. Launch-argumentet
`--skip-auth` aktiverer en lokal utviklingssesjon bare i DEBUG. Lokal profil opprettes automatisk ved første åpning; brukeren kan
velge Apple/e-postkonto som sekundær handling. Demo har eget lager.

## Implementert

### Porsjonslogging, avgrenset oppdatering 2026-10-02

Lokalt implementert støtte for antall basert på eksisterende, dokumenterte
porsjoner og pakningsmengder. Gram/ml er tilgjengelig når porsjon mangler.
Antall, navn, kilde, enhet og mengde per porsjon lagres som historisk snapshot
og bevares ved redigering, gjenbruk, lagrede måltider og eksport. Egne nye
porsjoner inngår ikke i første versjon. Ingen stykkvekt utledes fra varenavn.

Tillegg i synkkontrakt v1 og migrasjon `20261002120000_portion_logging.sql`
er verifisert lokalt med 69 databasetester, SQL-lint og 10 Deno-kontrakttester.
77 målrettede Swift-tester var grønne før pause. UI-testene for porsjonslogging
med omstart/redigering ved største tilgjengelighetstekst og logging på tidligere
dag er grønne. Manuell VoiceOver-kontroll og fysisk iPhone gjenstår før release.
Ingen serverdeploy eller produksjonsmigrasjon er utført. Produksjonssynk
forblir deaktivert. Se [implementeringsplanen](portion-logging-implementation-plan.md).

### iOS

- Førstegangsbruk åpner matvaresøk direkte med automatisk lokal profil, kort
  personverninformasjon og valgfri innlogging. Skann/manuell finnes på samme
  flate. Bekreftet lokal logging eller «Gå til Hjem» avslutter onboarding;
  måloppsett finnes under Profil → Daglige mål. Tidligere fullført onboarding
  bevares. Ingen nye mål opprettes automatisk.

- Morgensjekk er tatt ut av Hjem inntil videre (2026-10-03). Vektregistrering
  og eksisterende historikk beholdes i Oversikt. Innsjekkimplementasjonen og
  lokal status beholdes uten aktiv inngang eller opprettelse ved app-roten.

- Strekkodeoppslag/cache samles i `BarcodeLookupRepository`. OFF-produkter har
  30 dagers ferskhet og manuell oppdatering på produktkortet, med separate
  skannefeil for ukjent produkt, ufullstendig næring og nettverksfeil. Private
  produkter og historiske loggverdier beskyttes ved katalogoppdatering.
  Fast dekningskontroll er beskrevet i produksjonsberedskap; første baseline
  med norske butikkvarer er ennå ikke gjennomført.

- Navngitte lagrede måltider kan opprettes fra en måltidsgruppe i Logg,
  redigeres/slettes, vises i Loggfør-arket og loggføres atomisk til valgt dato
  og måltidskategori med samlet angre. Se [scope](saved-meals.md).

- Gjenbruk av gårsdagens enkeltmåltid på Hjem med forhåndsvisning, redigerbare
  mengder, valgfri kcal per vare, lokal atomisk lagring og angre. Se
  [scope og brukertest](meal-reuse.md).

- SwiftUI-app med fem hovedinnganger: Hjem, Søk, Loggfør, Oversikt og Profil.
- Hjem prioriterer dagsstatus og måltidskort uten en duplisert generisk
  søk-/skannerad. Søk og skanning er fortsatt tilgjengelig fra den vedvarende
  Loggfør-handlingen og Søk-fanen; legg-til fra måltidskort beholder
  måltidskonteksten.
- Lokal SQLite-lagring for mål, matlogger, produkter, favoritter,
  skannehistorikk, vekt, produktmatching, Matvaretabellen-cache og synkkø.
- Gjeldende lokalt skjema er v7, med vannlogging. Migrasjonen til v6 inkluderer kompatibilitet med produktutkast og kataloginnsendinger fra utviklingsbranchen. Tabellene bevares ved oppstart og inngår i lokal sletting; redigeringsflytene er ikke aktivert på main.
- Formell, transaksjonell versjonering av det lokale SQLite-skjemaet via
  `PRAGMA user_version`; eksisterende uversjonerte databaser migreres til v1
  uten å slette domenedata.
- Feil ved åpning eller migrering beholder databasefilen urørt og viser en
  blokkerende feiltilstand i stedet for å krasje eller starte med et tomt lager.
  Uleselige JSON-rader logges diagnostisk uten å bli slettet.
- Logging med mengde og bevart enhet (`g`/`ml`), måltid, kalorier og
  makronæringsstoffer. Eldre data uten enhet tolkes som gram.
- Måltidsrommet åpner valgt måltid og dato fra Hjem, med rullbar måltidsvelger,
  produktbilder, redigering/flytting, sletting med angre og sekundær hel-dagsvisning.
  Måltidstotaler inkluderer alle varer uavhengig av søk.
- Dagsnavigasjon med piler og kalender på Hjem og i Logg. Valgt dato følger
  dagsoppsummering, måltidsliste og nye registreringer, også for fremtidige
  datoer.
- Dagsoppsummering og gruppering av logger per måltid.
- Oversikt med dagens energi, sju dagers oversikt, makroer mot mål
  og vektregistrering. Måltidsfordelingskortet er fjernet. Kalorier og tilgjengelige makroverdier
  vises også når brukeren ikke har opprettet mål.
- EAN- og GS1 Data Matrix-skanning med produktoppslag mot Open Food Facts API v3.
  Fra GS1 Data Matrix brukes bare kontrollsiffervalidert GTIN (AI 01); dato, lot
  og andre sporbarhetsfelt forkastes lokalt. Gyldige treff
  får stabil identitet fra kilde + strekkode og caches lokalt uten å opprette
  `product.upsert`-hendelser. Dokumenterte væskemengder og næringsgrunnlag per
  100 ml bevares som milliliter uten å gjette tetthet eller konvertere til gram.
- Cachede Open Food Facts-produkter brukes uten nettverkskall i 30 dager. Eldre
  treff vises fortsatt umiddelbart og revalideres én gang per strekkode i
  bakgrunnen; ved feil beholdes snapshotet og nytt forsøk utsettes i 24 timer.
- Kombinert matsøk: 2 118 råvarer fra en normalisert Matvaretabellen-snapshot
  følger appen og søkes lokalt uten nett; eksplisitt navnesøk etter merkevarer
  går til Open Food Facts. Snapshotet bevarer Matvaretabellen-ID og manglende
  valgfrie verdier som `null`; rader uten komplett kcal-/makrogrunnlag tas ikke
  inn, fordi manglende næringsverdier ikke skal gjettes som null.
- Open Food Facts-kall bruker identifiserende app-/kontakt-header og kort
  nettverkstimeout, og 429-svar bevarer eventuell `Retry-After`. Også
  strekkodetreff uten komplett kcal-/makrogrunnlag avvises fremfor å fylle
  manglende verdier med null. Navnesøk sendes bare eksplisitt med Søk-knappen
  eller tastaturets søkehandling, ikke fortløpende per tastetrykk.
- Backend- og Open Food Facts-kall bruker en felles transportgrense med
  eksplisitt timeout og egne feil for offline, timeout og brutt forbindelse.
- Brukeropprettede produkter har lokal eierbinding, følger med ved bekreftet
  kobling av lokal profil til konto og slettes sammen med eierens lokale data.
  Ekstern katalogcache er fortsatt felles, lokal cache og synkroniseres ikke.
- Favoritter, nylig brukte produkter og skannehistorikk.
- Persondetaljer, målberegning og valgfri vektregistrering.
- Personlige målforslag er avgrenset til voksne med komplett, støttet
  beregningsgrunnlag. Appen gjetter ikke et generelt kaloriforslag når grunnlaget
  mangler, og standard makroprofiler ligger innenfor NNR 2023-intervallene.
- Egen redigeringsskjerm for daglige mål med utkast, feltvalidering, eksplisitt
  godkjenning av nye beregningsforslag og lagringsfeil som bevarer input.
  Skjermen viser alltid kalori- og makrofelt.
- Eksport av brukerdata.
- ViewModels og repository-grenser for sentrale features.
- Minimumsplattform iOS 17. Logging bruker en kompakt, ikke-modal bekreftelse
  med angre; globale feil presenteres ved app-roten, og standardmåltid velges
  etter lokal tid.

### Local-first og synk

- Normativ offline-funksjonalitet, brukerstatus og grensen mellom v1-retry og
  fremtidig flerenhetskonflikt er dokumentert i `offline-behavior.md`.
- Lokale domeneskrivinger oppretter versjonerte synkhendelser.
- Synkkøen støtter pending, in-flight, ack, retry, dead-letter og bounded
  backoff. Køen vekkes ved `nextRetryAt` og når nettforbindelsen kommer tilbake;
  permanent avviste hendelser beholdes for manuelt nytt forsøk.
- Køstatus teller pending, in-flight og dead-letter separat. Hjem og
  Innstillinger skiller mellom bare lokal lagring, offline, aktiv synk,
  planlagt retry og feil som krever handling. Permanente feil viser hendelsestype
  og årsak og kan prøves på nytt enkeltvis.
- En synkkjøring fortsetter gjennom flere batcher på inntil 50 hendelser til
  køen er tom eller en batch krever retry/handling.
- Hendelsesformatet er dokumentert i `sync-contract-v1.md`.
- Synkmotoren kan sende batcher og behandle bekreftede og avviste hendelser.

### Legacy-backend (NestJS/Prisma)

Punktene her beskriver bevart legacy-kode, ikke appens aktive serverplattform.

- Synkkontrakt og Prisma-modeller for brukereide lagrede måltider og elementer,
  med atomisk upsert, idempotens og eierskapskontroll.

- NestJS-applikasjon med health-, auth-, Prisma- og sync-moduler.
- E-postregistrering/-innlogging med passordhashing, kortlivet JWT og roterende
  refresh-token, samt opt-in dev-login for lokal utvikling. Refresh-token lagres
  kun som hash på serveren og tokenparet lagres samlet i Keychain på iOS.
- API-et nekter å starte uten eksplisitt JWT-hemmelighet. Dev-login er alltid
  deaktivert i produksjon og krever eget flagg lokalt.
- Autentisert soft-delete av konto, token-revokering og permanent purge etter
  30 dager.
- Autentisert mottak av synkhendelser på `POST /v1/sync/events`.
- Validering av event-type, schema-versjon, batchstørrelse og payload.
- Streng validering av UUID-er og canonical base64. Replay av en event-ID
  bekreftes bare for brukeren som eier eksisterende inbox-rad.
- Prisma/PostgreSQL-modell for synk-inbox og relevante domenedata.
- Første versjonerte Prisma-migrasjon for PostgreSQL-skjemaet.
- Kontrakttest for sentrale synkgrenser og payload-skjemaer.
- PostgreSQL-integrasjonstest for duplikatlevering, atomisk inbox-skriving og
  eierskapskontroll ved produktoppdatering.
- Flertrinns produksjonscontainer kjører kompilert backend som ikke-root, med
  separat migrasjonsmål og health check. Produksjonskonfigurasjon validerer
  database, JWT-hemmelighet, port, proxy og CORS før oppstart.
- API-et setter sikkerhetsheadere, skjuler Swagger som standard i produksjon og
  begrenser global trafikk samt auth-, token- og synkkall per klient.
- Backend-CI bygger, tester, migrerer en midlertidig PostgreSQL-database, kjører
  integrasjonstester, stopper på kritiske dependency-funn og bygger runtime-imaget.

## Delvis implementert eller deaktivert

- `FeatureFlags.backendSyncEnabled` er `false`. Produksjonssynk er derfor
  deaktivert selv om klient- og backendkomponenter finnes.
- Synkkøen har eksplisitt lokal `ownerUserId`. Nye hendelser bindes atomisk til
  brukeren som eier domeneskrivingen, og opplasting filtreres på aktiv innlogget
  bruker. Brukerbytte/utlogging kansellerer planlagte retries. Eldre ikke-ferdige
  hendelser uten sikker eierbinding beholdes i `quarantined` og sendes aldri.
- `FeatureFlags.goalCalibrationEnabled` er `false`.
- Debug-sesjon aktiveres bare eksplisitt med launch-argumentet `--skip-auth`.
- Apple-innlogging og e-post/passord vises som valgfrie kontoalternativer.
  Google-innlogging er senere scope. Apple krever konfigurert Supabase Apple-provider og aktivert
  Sign in with Apple-capability før distribusjon.
- Manuell opprettelse av ukjente produkter finnes fra skanneflyten.
- Backend dekker ikke alle endepunktene i `specs/06-api-endpoints.md`.
  API-spesifikasjonen er derfor et målbilde med mindre kode viser noe annet.

## Ikke dokumentert som produksjonsklart

- Separat produksjonsmiljø og fullført pilot-/releaseport. Staging er tidligere
  dokumentert opprettet; dagens eksterne tilstand er ikke kontrollert her.
  Se `docs/production-readiness.md`.
- Faktisk overvåkning, alarmer og operativ mottaker. Krav og terskler er
  dokumentert, men ikke koblet til en leverandør.
- Backup- og restore-prosedyre for PostgreSQL.
- Full kontrakt-, retry-, idempotens-, eierskaps- og integrasjonstestdekning.
- App Store-klargjøring og eksplisitt release-godkjenning.
- Verifisert samsvar mellom faktisk databruk, samtykke og juridisk tekst.
- Produksjonsavhengighetene har kjente high/moderate audit-funn i den nåværende
  NestJS 10-stakken. CI stopper nye critical-funn; eksisterende funn må
  oppgraderes eller risikovurderes før offentlig produksjon.

## Gjeldende verifiseringsstatus

- iOS-app og testbundles bygger med lokalt skjema v4 per 2026-09-27. Nye
  målrettede tester dekker eierfiltrering og karantene ved migrering fra v3.
  Den underliggende SQLite-migreringen, eierfiltreringen og karanteneregelen er
  verifisert direkte. Selve XCTest-kjøringen gjenstår fordi CoreSimulatorService
  ikke kan starte disk-image-tjenesten i verifiseringsmiljøet.
- `npm run build`, synkkontraktstesten og auth-konfigurasjonstesten består per
  2026-09-24.
- Baseline-migrasjonen og PostgreSQL-integrasjonstesten består lokalt per
  2026-09-16. Testen verifiserer duplikatlevering, eierskapsavvisning og atomisk
  rollback av inbox-innslaget ved avvist domeneskriving.
- Den autentiserte HTTP-integrasjonstesten består lokalt. Den verifiserer JWT,
  401 uten token, delvis avvist batch, trygg replay etter tapt ACK og at avviste
  domeneskrivinger ikke etterlater inbox-data.
- iOS-testen for køgjenoppretting består: en `inFlight`-hendelse i en lukket
  SQLite-database kommer tilbake som `pending` med samme event-ID, payload og
  forsøksteller når databasen åpnes på nytt.
- Full iOS → HTTP → PostgreSQL-flyt består lokalt, inkludert replay med samme
  event-ID og databaseverifikasjon av inbox/eierskap.

### API-hardening – verifisert 2026-09-24

- Prisma-klienten er generert, alle tre migrasjoner er anvendt i lokal
  PostgreSQL, og sync-, HTTP-sync- og auth-integrasjonstestene består.
- iOS bygger på iPhone 17 / iOS 26.5. Hele enhetstestsuiten består: 80
  testfunksjoner / 93 kjøringer, inkludert strukturert backend-feil,
  auth-metadata, Open Food Facts-header/timeout/rate-limit, fulltekstsøk og
  avvisning av ufullstendige ernæringsdata.
- Produksjonssynk er fortsatt avslått. Produksjonsmiljø, hemmelighetsdistribusjon,
  backend-rate-limiting og overvåkning er ikke verifisert.

## Aktive tekniske sannhetskilder

| Tema | Sannhetskilde |
| --- | --- |
| App-sammensetting | `MatLogg/MatLoggApp.swift` |
| Feature flags | `MatLogg/App/FeatureFlags.swift` |
| Lokal lagring og skjema | `MatLogg/Services/LocalStore.swift` |
| Klientsynk og konto | `MatLogg/Services/SyncEngine.swift` og `SupabaseService.swift` |
| Synkformat | `docs/sync-contract-v1.md` og `supabase/functions/_shared/sync-contract.ts` |
| Aktiv serverdatamodell/RLS/RPC | `supabase/migrations/` |
| Legacy-datamodell | `backend/prisma/schema.prisma` og `backend/prisma/migrations/` |
| Varige valg | `docs/decisions.md` |

## Nærmeste tekniske milepæl

Før backend-synk aktiveres:

1. Etabler produksjonslignende miljø, hemmelighetsdistribusjon, rate limiting,
   overvåkning og rollback.
2. Kjør releaseportene i dette miljøet og hold `backendSyncEnabled` avslått til
   de er grønne.

Oppdater dette dokumentet når en funksjon flyttes mellom planlagt, delvis
implementert og implementert.

### Nettverks-, retry- og sesjonshardening – kontrollert 2026-09-27

- Nye og berørte Swift-kilder består syntaksparse, og den selvstendige
  HTTP-transporten består `swiftc -typecheck`.
- Målrettede tester er lagt til for offline, timeout, katalog-500/retry,
  Matvaretabellen-429, dead-letter og lagret retrytid.
- Appen bygger for generisk iOS Simulator. De 23 målrettede testene i
  `APIServiceTests`, `AuthServiceTests`, `AuthViewModelTests` og
  `SyncRetryTests` består på iPhone 18 Pro / iOS 27.0.
- Automatisk refresh ved 401 er implementert for autentiserte iOS-kall. Det
  opprinnelige kallet gjentas høyst én gang; ugyldig eller gjenbrukt
  refresh-token tømmer lokal sesjon og sender brukeren til innlogging.
- Backend bygger, Prisma-skjemaet validerer og enhetlige kontrakt-/konfigtester
  består. Auth-integrasjonstesten dekker også samtidige refresh-forsøk, utløpte
  tokens og opprydding av utløpte sesjoner. Alle migrasjoner og backendens
  auth-, synk- og autentiserte HTTP-integrasjonstester består mot lokal
  PostgreSQL i Docker. Dette er fortsatt ikke en staging- eller
  produksjonsverifisering, og produksjonssynk forblir deaktivert.

### Daglige mål – verifisert 2026-09-29

- Appen bygger for iOS Simulator, og 19 målrettede tester i `DailyGoalsTests`
  og `OnboardingViewModelTests` består, inkludert dekoding av eldre mål-JSON.
- UI-testen bekrefter at eldre Safe Mode-preferanser ikke lenger skjuler
  målfeltene. Hele `DailyGoalsUITests` har fortsatt én feil fordi
  forslags-testen ikke oppretter nødvendige persondetaljer før den forventer et
  beregnet forslag; fire øvrige tester består.
- Arkitekturkontroll: utkast, beregning og validering eies av ViewModels;
  avhengigheter settes sammen ved app-roten; eksisterende lokal mål/event-
  transaksjon gjenbrukes. Ingen nye arkitekturavvik eller synkkontraktsendringer.
- Ikke verifisert på fysisk enhet eller med manuell VoiceOver-opplesning.
  Dette er funksjonsverifisering, ikke en produksjonsgodkjenning.

### Tryggere målforslag – verifisert 2026-09-23

- Appen bygger for generisk iOS Simulator etter at aktivitetsbasert fallback og
  udokumentert formelkonstant ble fjernet.
- Alle 68 enhetstestene består på iPhone 17 / iOS 26.5, inkludert nye tilfeller
  for manglende data, alder under 18, annet/ikke oppgitt formelgrunnlag og de nye
  makroprofilene.
- `DailyGoalsUITests` ble forsøkt, men Xcode fikk ikke materialisert UI-test-
  runneren og kjøringen ble avbrutt etter omtrent fem minutter uten testresultat.
  Endret onboardingtekst og deaktivert forslagstilstand er derfor ikke
  ende-til-ende-verifisert i denne kjøringen.

### Dagsnavigasjon – verifisert 2026-09-22

- Appen bygger for iPhone 17 / iOS 26.5 med aktiv arm64-arkitektur.
- `LogViewModelTests` består, inkludert lagring mot eksplisitt historisk og
  fremtidig dato.
- UI-testen for Hjem dekker navigasjon til både gårsdagen og morgendagen, med
  datoavhengig overskrift. Lokal kjøring ble avbrutt før resultat på brukerens
  ønske; scenariet gjenstår derfor å verifisere.
- Ikke verifisert på fysisk enhet eller med manuell VoiceOver-opplesning.

## Vannlogging (2026-09-30)

Implementert lokalt: kompakt vannkort på Hjem, ett trykk per glass, valgt dato,
korrigering ved å fjerne siste glass, profileierskap og eksport/sletting. SQLite-versjon 7 skriver
glass og synkhendelse atomisk. Supabase har additive `water.upsert`/`water.delete`
og egen migrasjon; migrasjonen må verifiseres og rulles ut før synk kan aktiveres.
Legacy NestJS støtter ikke vannevents og er ikke målplattform for denne funksjonen.

## Demomodus for presentasjon (2026-09-30)

DEBUG-versjonen har demokontroller bare i Profil. Ingen demorad vises over andre skjermer.
Demo lagres separat fra vanlige data og bruker lokal, fiktiv profil uten
serversynk. Datasettet inneholder 56 dagers variert mat-/vannlogging, vekthistorikk,
favoritter og fire lagrede måltider med næringsdata fra medfølgende Matvaretabellen.
Valgt modus og demoendringer beholdes etter omstart. Tilbakestilling krever
bekreftelse og berører bare demoen. Vanlig modus er tom bare når den vanlige
profilen ikke har registreringer fra før.

Verifisert på iOS 26.5-simulator: 15 målrettede Swift-tester (demo og profil) og
én UI-test for bytte begge veier og gjenoppretting av demomodus etter omstart.
Produksjonsutrulling inngår ikke; release-bygg og fysisk enhet er ikke verifisert.

## Søk og produktbilder (kontrollert mot kode 2026-10-01)

Søkeopplevelsen er innlemmet i `main`: direkte søkefelt, lokale treff under
inntasting, eksplisitt eksternt søk, favoritter, nylig brukt og manuell
registrering. Se `design-and-user-flow.md` og `search-implementation-plan.md`.

Manuell produktregistrering støtter valgfritt kamera-/bibliotekbilde.
`Product.localImageData` lagres lokalt og inngår ikke i `ProductSyncPayload`.
Eksisterende produktbilder bruker separat cache via `ProductImageRepository`.
Dette er kodekontroll, ikke en ny funksjons- eller enhetstest.

### Første logging – verifisert 2026-10-02

- Simulatorbuild og 18 målrettede AuthViewModelTests består, inkludert
  automatisk lokal oppstart, gjenåpning, kjent konto med mislykket restore,
  valgfri innlogging og avbrutt lokal datatilknytning.
- 14 LogViewModelTests består, inkludert repositoryfeil og Angre.
- testFirstLoggingWithoutAccountAndRelaunch og
  testFirstLogCanBeSkippedWithLargeText består på en dedikert iPhone 17 Pro
  med iOS 26.5. Lokalt treff er trykkbart med tastatur åpent; veien bruker
  to trykk pluss tekstinntasting med foreslått mengde og måltid. Stor tekst
  bruker rullbar, vertikal layout; tastaturet kan lukkes med Ferdig.
- Kontrollert mot arkitekturprinsippene: ingen ny IO i views/AppState,
  eksisterende injiserte søke- og lagringsgrenser gjenbrukes, og lokal
  domeneskriving/synkhendelse, kilde/enhet og eierskap er bevart. Ingen
  arkitekturavvik eller endring i synkkontrakten.
- Ekte Apple-innlogging, fysisk kamera og manuell VoiceOver-gjennomgang
  er ikke verifisert i denne endringen. Dette er ikke en produksjonsgodkjenning.

## Lokal lansering: verifisert 3. oktober 2026

Explicit localOnly-policy sperrer domenesynk uavhengig av backendflagget.
Status, datatapsinformasjon og eksporttekst er samordnet. Filbeskyttelse er
verifisert fysisk, og gamle eksporttempfiler ryddes best-effort etter 24 timer.
76 målrettede enhetstester og tre fysiske UI-flyter bestod. Ingen backenddeploy,
kjøp eller produksjonsutrulling. Restore, aktive konto-/personvernporter og
visuell runtime-advarsel gjenstår; se [QA-resultater](production-readiness.md).
