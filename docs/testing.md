# Testing

MatLogg bruker risikobasert testing. Datatap, feil ernæringsberegning,
auth/eierskap, synk/idempotens, sletting og personvernvalg prioriteres foran ren
visuell dekning.

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
