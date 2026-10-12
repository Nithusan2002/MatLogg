# Testing

MatLogg bruker risikobasert testing. Datatap, feil ernæringsberegning,
auth/eierskap, synk/idempotens, sletting og personvernvalg prioriteres foran ren
visuell dekning.

## Måling av testdekning

Kjør fra repo-roten med Deno 2.5.4 og en dedikert QA-simulator:

```bash
npm run functions:coverage
bash scripts/measure-test-coverage.sh ios 'platform=iOS Simulator,name=<QA-simulator>'
```

Hver kjøring får en ny mappe under ignorert `build/coverage/`, med commit,
arbeidstrestatus, verktøyversjon og testlogg. iOS kjører hele `MatLoggTests`
med kode-dekning og skriver `tests.xcresult`, `report.json` og `report.txt`.
Rapporter app-targetet `MatLogg.app` separat fra avhengigheter og testkode.
Deno skriver linje-/grendekning, LCOV og HTML under `profiles/`. Dekningen
omfatter bare lastede moduler; dagens tester laster `_shared/sync-contract.ts`
og `_shared/account-deletion.ts`, ikke HTTP-handlerne eller `_shared/client.ts`.

Supabase CI lagrer rapportene som artifacts, kjører hele iOS-enhetstesttargetet
og fire UI-tester for første logging, redigering med omstart, samlet
sletting/Angre og vannlogging med omstart. Testfeil stopper jobben; det er
foreløpig ingen prosentbasert gate. pgTAP og HTTP-/integrasjonstester
rapporteres som beståtte scenarioer, ikke som en felles kode-dekningsprosent.

Måling 2026-10-12 med Deno 2.5.4:

| Område | Linjer | Grener | Resultat |
| --- | --- | --- | --- |
| Delte Edge-moduler før nye tester | 89,8 % | 76,3 % | 15 tester bestod |
| Delte Edge-moduler etter nye tester | 97,1 % | 93,3 % | 19 tester bestod |
| iOS app-target, enhetstester | 32,57 % | Ikke grenmålt | 380 tester bestod |
| iOS Services + ViewModels | 82,33 % | Ikke grenmålt | Delmengde av app-targetet |
| PostgreSQL/RLS | Ikke linjemålt | Ikke grenmålt | 101 kontroller i 8 filer bestod |
| Legacy `backend/src`, vanlig `npm test` | 28,27 % | 70,51 % | 6 testskript bestod |

Databasemålingen brukte en ny lokal instans med prosjekt-ID
`matlogg-coverage-qa`, nye migrasjoner og syntetiske testdata på port 56322.
Eksisterende lokale instanser ble ikke endret. Legacy ble målt med Node 24,
V8-profiler og c8 10.1.3 (`--all --src backend/src --include 'backend/src/**/*.ts'`).
Legacy-tallet inkluderer umålte filer som 0 % og utelater egne Apple- og
database-/HTTP-integrasjonstester; det er ikke dekningen av hele backend-testpakken.
Kontoslettingens eksisterende ende-til-ende-test bestod mot samme lokale instans:
Auth-sletting, nektet innlogging, produktsletting, eierskapsisolasjon og gjentatt purge.

Første lokale iOS-kjøring fant to feil i migrasjonstestgrunnlagene: de beholdt
`food_logging_drafts` da de ble merket som eldre skjema. Testgrunnlagene ble
rettet uten endring i produksjonsmigrasjonene. Lokal Xcode 27.0 / iOS 26.5
hang under testavslutning; verifiseringen ble derfor flyttet til et rent CI-miljø.

[CI-kjøring 38217326998](https://github.com/Nithusan2002/MatLogg/actions/runs/38217326998)
på testcommit `1908c67` med Xcode 26.2 er grønn: alle 380 enhetstester i 46
suiter, fire UI-tester, 101 databasekontroller, kontosletting ende-til-ende og
19 Deno-tester bestod.
Dekningsartifactene ble lastet opp og iOS-rapporten lest tilbake.
App-targetet har 14 060 av 43 164 kjørbare linjer dekket. Gruppen Services +
ViewModels er definert som filer under disse to mappene: 9 765 av 11 861
linjer. Dette er en avgrenset gruppe, ikke en prosent for alle typer
kjernelogikk. Enhetstestene gir lav dekning av SwiftUI-visninger, som inngår i
app-targetets total. UI-testresultatene holdes separat fra denne baseline.

UI-kjøringene avdekket to faktiske feil: en gammel loggbekreftelse i app-skallet
kunne dekke slettingskvitteringens Angre, og appen krasjet ved redigeringslagring
med `EXC_BAD_ACCESS` i callbacken som overførte valgfri `PortionSelection`.
Tidligere loggbekreftelser lukkes nå når valgmodus starter. Redigeringen bruker
én uforanderlig `LogEditRequest` og en eksplisitt `@MainActor`-callback på begge
inngangene. Mengde, måltid og historisk porsjon overføres videre til samme
ViewModel/repository; lagring, synkformat og næringsberegning endres ikke.
UI-testen trykker Angre straks, kontrollerer opprinnelig antall og nye ID-er
etter gjenoppretting, og ruller fram rader før de undersøkes. Kontrollen av
samme logg-ID, dato og valgt måltid etter redigering og omstart beholdes.

Workflowen laster nå opp enhetsrapporten før UI-testene og bruker
`test-without-building` for UI, med eksplisitte tidsgrenser. Begge jobbene,
simulatoropprettelsen og artifact-opplastingen er verifisert i sluttkjøringen.
CI oppretter en egen iPhone 16 Pro via `scripts/create-qa-simulator.sh` fra
nyeste tilgjengelige iOS-runtime som støttes av valgt SDK, og bruker dens ID.
Dette erstatter antakelsen om hvilke simulatornavn runneren har ferdig opprettet.
CI-verifiseringen gjelder testgrenen, og omfatter ikke øvrige lokale
arbeidsendringer som ikke er med i dens commit.
Måleskriptene er syntakskontrollert med `bash -n`, og egen diff med
`git diff --check`. Simulatorhjelperens kommandoargumenter ble også kontrollert
med erstatninger ved CLI-grensen: kontrollen fanget en feil før retting og
returnerte bare simulator-ID etter retting. Ingen arkitekturavvik er innført:
presentasjonstilstand håndteres i UI, redigeringsstate og input i ViewModel,
og eksisterende repository-/transaksjonsgrenser er bevart.

Supabase-transport og varig retry (2026-10-12):

Verifisert på commit `b8d9273` i [grønn CI-kjøring](https://github.com/Nithusan2002/MatLogg/actions/runs/38223522816):
392 iOS-enhetstester i 48 suites, alle fire UI-tester og serverjobben bestod.
Ny linjedekning med samme målemetode:

| Filomfang | Linjer | Dekning |
| --- | --- | --- |
| Hele iOS-app-targetet | 14 193 / 43 168 | 32,88 % |
| `Services/` + `ViewModels/` | 9 898 / 11 865 | 83,42 % |
| `SupabaseService.swift` | 84 / 190 | 44,21 % |
| `SyncEngine.swift` | 153 / 183 | 83,61 % |
| `LocalStore.swift` | 2 718 / 3 085 | 88,10 % |

Dette erstatter iOS-tallene fra baseline ovenfor for den testede committen.
Deno-modulenes måleomfang er uendret; HTTP-integrasjonstesten måles ikke med Deno-dekning.
Lokal `xcodebuild build-for-testing` for iOS Simulator, shell-syntakskontroll,
Python-kompilering og `git diff --check` bestod også.

- `SupabaseTransportTests` bruker den ekte Swift-SDK-en med injisert URLSession
  og isolert HTTP-stub. Den kontrollerer wire-format/base64, batch-/payloadgrenser,
  delvise svar, 401/503/429/502, relay-feil, timeout og ugyldige suksessvar.
- `SupabaseQueueIntegrationTests` kobler transporten til `SyncEngine`,
  `DatabaseService` og en faktisk SQLite-fil. Den kontrollerer offline-lagring,
  delvis ACK, vedvarende backoff, omstart, in-flight-gjenoppretting og ny levering
  med samme event-ID/payload uten tap av lokale logger. Retry gjøres klar eksplisitt
  i testen; dette er ingen måling av automatisk ventetid.
- `bash supabase/tests/run-sync-http-e2e.sh <disponibel-lokal-workdir>` tester
  ekte lokal Auth → Edge Function → PostgreSQL/RLS. Den kontrollerer manglende,
  ugyldig og utløpt token, deaktivert synk, metode/JSON/envelope-validering,
  delvis batch, ukjent schema, replay etter antatt tapt ACK, eierskap og 51-eventsgrensen.
  Kun loopback godtas. Testen oppretter syntetiske brukere, gjenoppretter
  `sync_enabled` og sletter testbrukerne etterpå. Bruk kun disponibelt QA-prosjekt.
  Kontrollen inngår i Supabase CI og bestod også lokalt på port 56321.

`SupabaseService` kan nå få SDK-klienten injisert. Produksjonsinitializer,
auth-oppsett, wire-kontrakt og domenelagring er uendret. Ingen arkitekturavvik:
IO-grensen er injiserbar, og eksisterende repository-/transaksjonsgrenser beholdes.

Samlet iOS → lokal Supabase (2026-10-12):

`LiveSupabaseSyncTests` og `scripts/run-live-sync-e2e.py` bestod med to separate
iOS-testprosesser på Xcode 27.0 / iOS 26.5. Hver prosess kjørte nøyaktig én test;
helperen avviser en grønn kjøring med null utførte tester.

Første prosess logger et syntetisk produkt og en matlogg lokalt før opplasting,
og kontrollerer at serveren ennå ikke har loggen. Den bruker ekte Supabase Auth,
Swift-SDK, Edge Function og PostgreSQL. En testadapter holder det mottatte ACK-et
ved transportgrensen, slik at SyncEngine ikke får lagre det lokalt. Køen står
som in-flight når testverten avsluttes. Andre prosess krever en ny prosess-ID,
åpner samme SQLite-fil, kontrollerer identiske event-ID-er/payloads og leverer
på nytt gjennom SyncEngine. Resultatet er én matlogg og to inbox-rader (produkt
og logg) på serveren, bevart mengde/enhet/kcal og ingen ubekreftede lokale events.
Dette tester kontrollert prosessavslutning ved ACK-grensen, ikke fysisk nettutfall
eller vilkårlig krasj. Nedlasting og flerenhetskonflikter inngår ikke.

Testene er deaktivert i vanlig enhetstestkjøring. Helperen injiserer runtime-oppsett
via en midlertidig xctestrun-fil som slettes etterpå. Den godtar bare loopback og
QA-prosjekt-ID `matlogg-coverage-qa` eller `matlogg-live-sync-qa`, oppretter en syntetisk
bruker og rydder egne serverdata/bruker og gjenoppretter serverflagget også ved feil.
Den vanlige klientens produksjonsflagg endres ikke. Start kun en disponibel QA-database.

```bash
xcodebuild build-for-testing -project MatLogg.xcodeproj -scheme MatLogg \
  -destination 'platform=iOS Simulator,id=<QA-ID>' CODE_SIGNING_ALLOWED=NO
python3 scripts/run-live-sync-e2e.py \
  --workdir <disponibel-lokal-QA-workdir> \
  --xctestrun '<DerivedData/MatLogg-.../Build/Products/MatLogg_...xctestrun>' \
  --simulator <QA-ID>
```

Suksessrapport og begge xcresult-bundler ligger lokalt under
`build/coverage/live-sync.gx2lk_a4/`. Denne kjøringen gjelder lokal arbeidskopi;
den er ikke kjørt i GitHub CI. CI har separate iOS-/serverjobber og mangler den
samlede testens lokale Docker-backend. Ingen produksjonskode, kontrakt eller
arkitekturgrenser er endret i denne runden; kun testkode, testhelper og dokumentasjon.

Midlertidige RPC-feil og automatisk retry (2026-10-12):

HTTP-handleren ligger nå i `_shared/sync-handler.ts` med en injiserbar RPC-grense;
`sync-events/index.ts` kobler fortsatt til de samme ekte auth-/Supabase-klientene.
Deno-testene fremprovoserer returnerte RPC-feil fra `is_sync_enabled`,
`consume_sync_quota_v1` og `apply_sync_event_v1`. De kontrollerer 500 før
apply ved config/quota-feil, delvis 201/`SERVER_ERROR` ved apply-feil og vellykket
ny levering med samme event-ID når feilen fjernes. Dette er feilinjeksjon ved
RPC-grensen, ikke faktiske driftsavbrudd i PostgreSQL.

`AutomaticSyncRetryTests` kobler ekte Supabase Swift-SDK, HTTP-stub, SyncEngine
og SQLite. Tre feilforløp bruker vanlig timer og Backoff (10–15 sekunder),
uten manuell retry, endring av køen eller akselerert klokke. De kontrollerer
utsatt retry, samme event-ID/payload, bevart lokal logg, ACK etter gjenopprettet
HTTP-svar og vedvarende ferdig kø etter gjenåpning.

Verifisert lokalt: 3 nye Deno-handler-tester, 13 synkkontrakttester, Deno check/lint,
10 iOS-tester i transport-/retry-suitene (inkludert tre retry-cases, totalt 44,67 s)
3 SQLite-/transport-integrasjonstester og HTTP-regresjon mot ekte disponibel Supabase. Resultatbundle:
`build/coverage/automatic-retry.xcresult`. Ingen API-kontrakt, autorisering,
produksjonsflagg eller databasemigrasjon er endret. Avhengigheter injiseres ved
IO-grensen; local-first-transaksjoner og eierkontroll beholdes uten arkitekturavvik.

Gjenværende oppfølging:

1. Legacy-integrasjonstester vurderes separat så lenge cutover trenger dem.
   Øk ikke legacy-dekningen bare for å forbedre et samlet prosenttall.

Risikospesifikasjonens mål om over 60 % kjernelogikk kan først brukes som gate
når filomfang og målemetode er definert. Kritiske feilscenarioer skal være
testet uansett prosent. Produksjonssynk holdes fortsatt deaktivert.

## Forutsetninger

- Xcode med en kompatibel iOS-simulator
- Node.js og npm for Supabase CLI og legacy-backend
- Docker når tester krever lokal Supabase/PostgreSQL
- backend-avhengigheter installert med `npm install` i `backend/`

## iOS

### Release-størrelse

Kjør `bash scripts/measure-app-size.sh` for et lokalt, signert Release-arkiv
og eksport med alle enhetsvarianter. Krever lokal Apple Development-identitet
og gyldig provisioningprofil. Ingen opplasting utføres.

Resultater lagres under ignorert `build/app-size/`: `bundle-size.json` viser
arkivets ukomprimerte appfiler, `build-context.txt` viser commit, lokale endringer
og Xcode-versjon, og `export/App Thinning Size Report.txt` viser komprimerte og
ukomprimerte enhetsvarianter. Eksporten bruker development-signering; endelig
App Store-størrelse må bekreftes i App Store Connect. Sammenlign samme variant,
Xcode-versjon og eksportmetode ved senere målinger. Skriptet kan også få en
egen outputmappe som første argument; bruk en ny mappe for hver kjøring.

Baseline 2026-10-01: Xcode 27.0 (27A266a), commit `dd4503c` med lokale
arbeidsendringer. Signert Release-arkiv: 8 767 696 byte totalt, hvorav kjørbar
kode 6 385 312 byte, `Assets.car` 1 852 472 byte og matvaretabell 480 672 byte.
Universal development-eksport: 4,4 MB komprimert / 8,8 MB ukomprimert.
iPhone- og iPad-variantene: 3,5 MB komprimert / 7,9 MB ukomprimert.
Rårapporter og eksakt arbeidskontekst finnes lokalt i
`build/app-size/baseline-2026-10-01-verified/`; arkiver og signerte eksportfiler
skal ikke sjekkes inn i Git. Dette er en størrelsesreferanse, ikke en releasegodkjenning.

List schemes og tilgjengelige simulatorer:

```bash
xcodebuild -list -project MatLogg.xcodeproj
xcrun simctl list devices available
```

Bygg appen uten signering:

```bash
xcodebuild build \
  -project MatLogg.xcodeproj \
  -scheme MatLogg \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO
```

Kjør enhets- og integrasjonstestene med navnet på en installert simulator:

```bash
xcodebuild test \
  -project MatLogg.xcodeproj \
  -scheme MatLogg \
  -destination 'platform=iOS Simulator,name=<simulatornavn>' \
  CODE_SIGNING_ALLOWED=NO
```

Eksisterende iOS-tester dekker blant annet:

- stabil fanerekkefølge og canonical måltidsverdier
- kalorimål og grenseverdier
- ViewModel→repository ved logging og sletting
- opprettelse av synkhendelser
- reset av in-flight-hendelser og retry/backoff

`DailyGoalsTests` dekker presis bevaring av mål, feltvalidering, avbryt,
lagringsfeil/retry, gjentatte lagretrykk, bakoverkompatibel dekoding, forslag og
gjenåpning av lokal database med tilhørende synkhendelse. `DailyGoalsUITests`
dekker målredigering med omstart, ugyldig input, avbryt, eksplisitt bruk av
forslag, eldre visningspreferanser og svært stor tekst. Øvrige kritiske
brukerflyter trenger fortsatt
utvidet UI-dekning før release.

Målrettet kjøring for daglige mål (legg til en installert simulator):

```bash
xcodebuild test -project MatLogg.xcodeproj -scheme MatLogg \
  -destination 'platform=iOS Simulator,name=<simulatornavn>' \
  -only-testing:MatLoggTests/DailyGoalsTests \
  -only-testing:MatLoggUITests/DailyGoalsUITests \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO
```

### Første logging

Kjør på en dedikert QA-simulator. UI-testene overstyrer lokal profiloppslag
ved første launch for å opprette en ny testprofil; ved gjenåpning fjernes
overstyringen og den lagrede profilen brukes. De sletter ikke domeneinnhold.

```bash
xcodebuild test -project MatLogg.xcodeproj -scheme MatLogg \
  -destination 'platform=iOS Simulator,name=<QA-simulator>' \
  -derivedDataPath /tmp/MatLoggFirstLogQA \
  -only-testing:MatLoggTests/AuthViewModelTests \
  -only-testing:MatLoggUITests/MatLoggUITests/testFirstLoggingWithoutAccountAndRelaunch \
  -only-testing:MatLoggUITests/MatLoggUITests/testFirstLogCanBeSkippedWithLargeText \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO
```

Testene dekker direkte lokalt søk med tastatur, lagring, Angre og omstart,
samt rullbare alternativer med stor tekst og eksplisitt «Gå til Hjem».
Sesjonstestene dekker også mislykket gjenoppretting av kjent konto, bevart
lokal profil ved innloggingsfeil og valgfri innlogging før første logging.

## Supabase

Fra repo-roten:

```bash
npm ci
npm run supabase:start
npm run supabase:reset
npm run supabase:lint
npm run supabase:test
npm run functions:test
```

`.github/workflows/supabase-ci.yml` kjører database-reset, lint, pgTAP,
Deno check/lint/test og målrettet iOS-bygg/test. pgTAP dekker blant annet RLS,
grants, `auth.uid()`, kryssbrukerangrep, slettet profil og purge.

## Legacy-backend under cutover

Fra `backend/`:

```bash
npm install
npm run build
npm test
```

Pull requests som berører `backend/` kjører også `.github/workflows/backend-ci.yml`:
låst installasjon, Prisma-generering, build, enhets-/kontrakttester, migrasjoner
og alle PostgreSQL-integrasjonstestene, kritisk dependency-audit og bygging av
produksjonscontaineren.

Gjeldende `npm test` kjører kontrakttesten i
`backend/test/sync-contract.test.ts`. Den validerer schema-versjon,
batch-/payloadgrenser, event-typer og utvalgte payload-skjemaer.

Ved endringer i Prisma-skjemaet:

```bash
npm run prisma:generate
npm run prisma:migrate
```

Migrasjoner skal valideres mot en ikke-produksjonsdatabase. Ikke test
destruktive migrasjoner mot eneste kopi av data.

## Manuell kontroll per endringstype

### UI og brukerflyt

- normal-, loading-, tom-, offline-, feil- og deaktivert tilstand
- Dynamic Type, VoiceOver, kontrast og touchflater
- tastatur, modalpresentasjon og tilbake-navigasjon
- næringsverdier samsvarer mellom synlig UI og tilgjengelighetstre
- raske kontekstskifter (for eksempel dato eller søk) der svar kan komme ute av
  rekkefølge; bare resultatet for siste valgte kontekst skal publiseres
- profiler hyppige flyter med SwiftUI Instruments ved ytelsesrelevante endringer:
  søk mens det skrives, mengdeinntasting, fanebytte og lange lister
- kontroller at `body` ikke utløser repository-/SQLite-kall, og at lister bruker
  batchlastede presentasjonsdata fremfor N+1-oppslag
- kontroller stabile `ForEach`-ID-er med duplikater, innsetting, sletting og
  omorganisering; bruk ikke `.id()` som generell kur mot re-rendering
- kontroller at hurtig lokal state bare invalidiserer den relevante delvisningen
  når skjermen også inneholder diagrammer, bilder eller store lister

### Ernæring og mål

- råverdi, enhet, porsjonsgrunnlag og kilde bevares
- manglende verdier blir ikke gjettet
- avrunding skjer bare ved visning der kontrakten tillater det
- ekstreme input og ikke-stigmatiserende tekst kontrolleres

### Local-first og synk

- brukerhandlingen lykkes uten nett
- domenedata og event skrives atomisk
- offline→online sender ventende hendelser
- timeout og prosessavbrudd mister ikke eventet
- samme `eventId` kan leveres flere ganger uten dobbel domeneskriving
- ukjent type/schema og delvis batch-feil håndteres eksplisitt
- to enheter og klokkeavvik følger dokumentert konfliktstrategi

### Backend, auth og personvern

- ugyldig input gir stabil, maskinlesbar feil
- identitet kommer fra verifisert token, ikke klientens `userId`
- bruker kan ikke lese, endre eller slette en annen brukers data
- tokens, persondata og produksjonsdata finnes ikke i logger eller fixtures
- sletting og eksport samsvarer med brukergrensesnitt og juridisk tekst
- ugyldige base-URL-er og annen runtime-konfigurasjon gir typede feil uten
  force unwrap eller prosesskrasj

## Krav før synk aktiveres

`FeatureFlags.backendSyncEnabled` skal forbli `false` til følgende er grønt:

- iOS bygger og relevante tester består
- backend bygger og kontrakttester består
- ende-til-ende-test mot PostgreSQL består
- retry, duplikatlevering og delvis feil er testet
- eierskap og autentisering er testet
- klient/server-kompatibilitet og utrullekkefølge er vurdert
- observability og en trygg rollback er definert

## Rapportering

Ved kodeendringer skal ferdigrapporten oppgi:

- kommandoer og testmiljø
- hva som bestod eller feilet
- hva som ikke ble testet
- gjenværende risiko
- go/no-go når endringen gjelder pilot eller release


### Strekkodecache og katalogoppdatering

Målrettet kontroll (velg en installert simulator):

```bash
xcodebuild test -project MatLogg.xcodeproj -scheme MatLogg \
  -destination 'platform=iOS Simulator,name=<simulatornavn>' \
  -only-testing:MatLoggTests/ProductSearchTests \
  -only-testing:MatLoggTests/BarcodeCatalogStorageTests \
  -only-testing:MatLoggUITests/MatLoggUITests/testSearchTabSupportsLocalSearchAndProductOpening \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO
```

Testene dekker ferskhetsgrensen, automatisk retry-pause, manuell oppdatering,
delte forespørsler, `Retry-After`, separate feiltilstander, forkasting av gamle
skanneresultater, endret måleenhet og beskyttelse av private varer/historiske
loggverdier. API-tester bruker syntetiske svar, ikke live leverandørdata.
Fysisk skanning, VoiceOver og faktisk varedekning kontrolleres før pilot.

### Måltidsrommet

Målrettet verifisering: `MatLoggTests/LogViewModelTests` dekker måltidstotaler,
separate søketreff, datoer, redigering og sletting/angre.
`MatLoggUITests/MatLoggUITests/testMealRoomOpensMealAndKeepsSelectionAcrossDates`
dekker inngang fra Hjem, måltidsvalg og datobytte med stor tekst.
`MatLoggUITests/MatLoggUITests/testMealRoomLogsAndEditsFoodForSelectedPastDay`
dekker registrering på tidligere dato og flytting til et annet måltid.
Begge UI-testene lagrer skjermbilder i testresultatet.

### Navigasjonsforenkling

`QuickLogTests` dekker lokal henting av gjenloggingsgrunnlag uten katalog-
eller nettsøk, retry og forkasting av et profilsvar etter reset. Testene dekker
også lokal manuell produktlagring, mengdevalg etter at skjemaet er lukket,
og forkasting av ventende produktvalg ved profilreset.
`testQuickLogManualOpensDirectlyAndCancelReturnsToQuickMenu` dekker direkte
åpning uten søkeskjerm, avbryt til hurtigmenyen og bevart dato.
`testDailyLogIsDirectAndSavedMealsRemainDiscoverable` dekker direkte dagslogg
uten filter, bytte mellom gjenbrukslistene og bibliotekinngangen fra bunnmenyen.
`testQuickLogManualRegistrationAndDirectHomeEditingKeepPastDate` dekker
manuell produktregistrering fra Loggfør, logging på tidligere dato og direkte
redigering fra Hjem med kontroll av flytting til Lunsj.
Testene bruker egne kontroll-ID-er slik at favoritt- og lagreknapper ikke
forveksles. Fysisk skanning og VoiceOver kontrolleres før pilot.

### Loggfør igjen i hurtigmenyen

`RepeatFoodTests` dekker profilfiltrering, framtidige registreringer, stabil
sortering, eksakt g/ml, gjeldende næringsdata, porsjonssnapshot og kontroll ved
endret grunnlag. Testene dekker også atomisk rollback ved hendelsesfeil,
retry, raske dobbelttrykk, kontekst-/profilbytte og Angre med eksakt logg-ID.
`RepeatFoodUITests/testRepeatPortionAndUndoKeepsOriginalLog` kontrollerer
kompakte nylige varer i Søk, synlig mengde/destinasjon i Loggfør-menyen,
direkte gjenlogging og bevart original etter Angre
med største tilgjengelighetstekst.

Målrettet kjøring: `xcodebuild test` med scheme `MatLogg`, en egen QA-simulator,
`-only-testing:MatLoggTests/RepeatFoodTests`,
`-only-testing:MatLoggTests/FoodSearchTests`,
`-only-testing:MatLoggTests/QuickLogTests`,
`-only-testing:MatLoggTests/LogViewModelTests` og
`-only-testing:MatLoggUITests/RepeatFoodUITests`.

### Porsjonslogging

`PortionLoggingTests` og `PortionImportTests` dekker antall/desimaler, nøyaktig
omregning, enhetsbytte, inkompatible og eldre heuristiske porsjoner, cache-ID-er,
historisk snapshot, JSON-bakoverkompatibilitet, atomisk rollback/retry, angre,
kopiering, måltidsgjenbruk, lagrede måltider, sist brukt og eksport.
`PortionLoggingUITests` logger to brød, gjenåpner appen og redigerer til tre med
stor tekst. Det syntetiske produktet aktiveres bare i Debug med `--portion-qa`.

Målrettet iOS-kjøring, med en installert QA-simulator:

```sh
xcodebuild test -project MatLogg.xcodeproj -scheme MatLogg \
  -destination 'platform=iOS Simulator,name=<QA-simulator>' \
  -only-testing:MatLoggTests/PortionLoggingTests \
  -only-testing:MatLoggTests/PortionImportTests \
  -only-testing:MatLoggTests/ProductSearchTests \
  -only-testing:MatLoggTests/LogViewModelTests \
  -only-testing:MatLoggTests/MealReuseTests \
  -only-testing:MatLoggTests/SavedMealsTests \
  -only-testing:MatLoggTests/SavedMealStorageTests \
  -only-testing:MatLoggUITests/PortionLoggingUITests \
  -only-testing:MatLoggUITests/MatLoggUITests/testMealRoomLogsAndEditsFoodForSelectedPastDay \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO
```

Backend: `functions:test` og `supabase:test` dekker porsjonssnapshot, UTF-8,
legacy/null-semantikk, logg og måltid, eierskap, retry og rollback.
Bruk en separat lokal testdatabase for migrasjonsreset; ikke reset utviklerens
eller staging-/produksjonsdata. Migrasjon og Edge Function må være på plass
før klienten sender det nye valgfrie v1-feltet. Produksjonssynk forblir av.

### Tidsmåling med Instruments

`PerformanceSignposts` sender intervaller også i optimaliserte Release/Profile-
bygg. Bruk Product → Profile på fysisk enhet, velg Time Profiler og legg til
os_signpost-instrumentet. Filtrer på subsystem `com.nithusan.MatLogg` og
kategori `Performance`. Intervallene inneholder bare statiske kodenavn.

- `Database.Total` / `Database.Execute`: total ventetid og utførelse på IO-køen.
  Metadata `operation` identifiserer repository-kallet. Differansen inkluderer
  køventing og gjenopptakelse av den ventende tasken.
  `Database.QueueWait` måler fra innsending til IO-closure-en starter;
  `Database.ResumeWait` måler fra rett før continuation.resume til tasken
  fortsetter etter await, også ved feil. ResumeWait inkluderer selve resume-
  kallet og executor-planlegging; det beviser ikke alene at MainActor blokkeres.
  Bruk metadata `operation=latestGoal(userId:)` for å undersøke målhenting.
- `Store.Summaries.*`, `Store.Products.*` og `Store.Transaction.*`: indre SQL/
  dekoding, aggregering og transaksjon, adskilt fra total tid med køventing.
  Transaksjonsintervallet inkluderer commit eller rollback.
- `Home.*` og `Log.*`: lasting av hjemoversikt og lokal matlogging. Oversikten
  kan oppdateres i en separat task etter logging; disse intervallene skal derfor
  undersøkes sammen, ikke summeres som én sekvens.
- `Search.FirstLocal`, `Search.Load`, `Search.ResultsToState`, `Search.Index`:
  første lokale state, full lasting, task frem til publisering og faktisk
  søkeberegning inne i actor-en. Første lokale state kan publiseres før den
  asynkrone treffberegningen er ferdig.
- `Catalog.*` og `Search.Remote*`: filinnlesing, parsing, projisering,
  sammenslåing, leverandør/cache, faktisk API-kall, filtrering og lokal cache.
  `Store.Open`, `Store.Migrate` og `Store.ResetInFlight` dekker databaseoppstart.

Gjenta kald oppstart, åpning av søk, tastetrykk, matlogging og datobytte.
Sammenlign første og senere kjøringer. Marker samme tidsområde i Time Profiler
for å finne CPU-arbeidet. Signpost-varighet er forløpt tid, inkludert venting;
intervaller kan overlappe og skal ikke summeres ukritisk. Intervallene avsluttes
også ved feil, kansellering og forkastede resultater. Slutten betyr derfor ikke
alltid at data ble publisert, og måler aldri ferdig tegnet skjerm.

Oppstart og UI: `Startup.RestoreContext`, `Startup.Compose`,
`Startup.RestoreSession` og `Startup.LoadHealthProfile` måler koordinering og
oppsett. `Startup.*Changed` og `Startup.ContentAppeared` er enkeltmarkører uten
brukerdata. `UI.AppRootBody`, `UI.RootBody`, `UI.TabBody` og `UI.HomeBody` måler
bare evaluering av view-verdier. De inkluderer ikke underliggende body-kall,
layout eller rendering. Bruk SwiftUI-instrumentet sammen med Time Profiler for
å se view-grafarbeid mellom intervallene og antall gjentatte evalueringer.
`Startup.Compose` dekker initializer-arbeid, men StateObject kan opprette
objektene senere; intervallet dekker derfor ikke hele objektinitialiseringen.

## Kontosletting og lokal opprydding

Målrettede iOS-suiter: `AuthViewModelTests`, `AuthServiceTests` og
`ProfileTests`. Kontroller at xcresult faktisk inneholder kjørte tester;
en vellykket testkommando med null tester er ikke verifisering.
`account_deletion.test.sql`, `account_deletion_access.test.sql` og
`002_sync_security.test.sql` dekker purge,
produkter, rate-limit-rader, alle domenekategorier, eierisolasjon og retry.

`bash supabase/tests/run-account-deletion-e2e.sh <lokalt-supabase-prosjekt>`
setter opp en midlertidig cron-secret og functions-server, kjører HTTP-testen
og rydder egne prosesser/hemmeligheter. Samme kontroll inngår i Supabase CI.

For manuell lokal ende-til-ende-kontroll må Supabase være startet med migrasjonene,
og funksjonene må serves med en lokal `PURGE_CRON_SECRET` i en ignorert eller
midlertidig env-fil. Kjør:

```sh
python3 supabase/tests/account-deletion-e2e.py \
  --workdir <lokalt-supabase-prosjekt> --env-file <lokal-env-fil>
```

Testen godtar bare localhost, leser lokale CLI-nøkler uten å skrive dem ut,
og oppretter/rydder syntetiske kontoer og produkter. Den tester innlogging,
serverbekreftelse, sperret innlogging, umiddelbar lesesperring med gammelt
token, purge, Auth hard-delete og eierisolasjon.
Bruk et isolert lokalt prosjekt: purge behandler alle forfalte kontoer i
testmiljøet. Hosted tester skal avgrenses til staging og syntetiske kontoer;
kontroller at ingen andre kontoer forfaller før en bulk-purge kjøres.

### Registreringsutkast

Målrettet verifisering på en dedikert simulator:

```bash
xcodebuild test -project MatLogg.xcodeproj -scheme MatLogg \
  -destination 'platform=iOS Simulator,name=MatLogg Draft QA' \
  -derivedDataPath /tmp/MatLoggDraftQA \
  -only-testing:MatLoggTests/LoggingDraftTests \
  -only-testing:MatLoggTests/MatLoggTests/schemaVersionSixMigratesAndReopensWithoutDeletingDrafts \
  -only-testing:MatLoggUITests/LoggingDraftUITests \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO
```

Testene bruker syntetiske data. UI-testen bruker debugprofilen på dedikert
simulator og forkaster eventuelt et tidligere utkast der, beholder et
syntetisk produkt og logger én testregistrering. Fysisk systemterminering og
VoiceOver må vurderes separat; UI-testen modellerer prosessavbrudd.

### Skjermbilder til landingssiden

`LandingCaptureUITests/testCaptureLandingScreens` er et eksplisitt opptaksverktøy.
Bruk en dedikert simulator og sett `TEST_RUNNER_MATLOGG_LANDING_CAPTURE=1`
foran `xcodebuild test` med `-only-testing:MatLoggUITests/LandingCaptureUITests`.
Testen tilbakestiller bare demoen og lagrer åtte navngitte `landing-*`-bilder
i xcresult. Den logger 60 g havregryn til dagens frokost én gang. Alle bildene tas uten
tastatur. Søkebildet bruker et presist produktsøk; et eget dagbokbilde tas
etter at bekreftelsen er lukket. Mengdebildet tas ved å åpne produktet igjen med den huskede
mengden på 60 g, uten å fokusere feltet eller logge en ekstra registrering.
Eksporter vedlegg med `xcrun xcresulttool export attachments` og kontroller
bildene visuelt før de erstatter `matlogg-web/public/screenshots/`.

### Historikktreff i matsøk

`FoodSearchTests` dekker tregrensen, presise søkeord, stabil rekkefølge,
deduplisering og tømming ved søke-/profilbytte. `RepeatFoodTests` dekker lokalt
historikkgrunnlag utover seks nylige varer, siste loggføring per produkt,
framtidige registreringer, eierskap, sletting og uendret synkkø ved lesing.
`FoodSearchLoadingTests` kontrollerer bevart lokal/katalog-lastestruktur.
`RepeatFoodUITests/testRepeatPortionAndUndoKeepsOriginalLog` kontrollerer også
«Tidligere logget», unik produktrad og åpning av produktkort med største tekst.
Kjør disse målrettet på en dedikert QA-simulator.

### Flervalg i dagsloggen

Målrettet kontroll: `LogViewModelTests`, `RenderPresentationTests`,
`SavedMealsTests` og `MealBatchStorageTests`. Disse dekker valg per logg-ID,
måltidsgrupper/dato, 50-varegrense, uavhengig batchkvittering, feil og
atomisk sletting/gjenoppretting med synkhendelser.

På en ledig dedikert QA-simulator kjøres også
`MatLoggUITests/testDiarySelectionDeletesAndRestoresWholeBatch` og
`MatLoggUITests/testDiarySelectionSavesOnlyChosenEntryWithLargeText`.
Testene oppretter syntetiske porsjonslogger med `--portion-qa`, kontrollerer
Angre og avbrutt/vellykket måltidslagring, og lagrer skjermbilder. VoiceOver
må fortsatt kontrolleres manuelt; UI-testene verifiserer ikke opplesning.
