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

## Apple Helse – målrettet verifisering

HealthIntegrationTests bruker syntetiske data, en fake HealthKitClient og egne
midlertidige databaser. SDK-samplekonverteringen testes uten HKHealthStore.
Testene dekker migrasjon 7→8, atomisk outbox, canonical lokale HealthKit-typer,
revisjoner/retry, presisjon/kilde/enhet, kopiering til valgt dato, sletting/angre,
delvis tilgang, 90-dagers import, anchor, cachefeil, manuell prioritet, frakobling,
profiloverføring og forsinkede native operasjoner. Kontroller også regresjonene
for måltidslagring, morgeninnsjekk, profil, gjenbruk og lagrede måltider.

```bash
xcodebuild test -project MatLogg.xcodeproj -scheme MatLogg \
  -destination 'platform=iOS Simulator,name=<simulatornavn>' \
  -only-testing:MatLoggTests/HealthIntegrationTests \
  -only-testing:MatLoggTests/MealBatchStorageTests \
  -only-testing:MatLoggTests/MorningCheckInTests \
  -only-testing:MatLoggTests/ProfileTests \
  -only-testing:MatLoggTests/MealReuseTests \
  -only-testing:MatLoggTests/SavedMealsTests \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO
```

HealthIntegrationUITests tester valg, tomtilstand, omstart og frakobling med
svært stor tekst og `--healthkit-fake`. Kjør separat med
`-only-testing:MatLoggUITests/HealthIntegrationUITests`.

Verifisert 2026-10-02 på iOS 26.5 / iPhone 17 Pro-simulator: 71 tester i seks
suiter grønne, hvorav 26 HealthIntegrationTests. HealthIntegrationUITests har
bestått; Release-simulatorbygg og norske usage descriptions er kontrollert.
`git diff --check` er grønn. Eksisterende testkilder har Swift 6-aktørvarsler;
appen har fortsatt Swift 5-konfigurasjon.

Dette er ikke en produksjonsgodkjenning: fysisk HealthKit-tilgang, signert
provisioning, Data Protection på låst iPhone og native retry/rettelser/sletting
må fortsatt testes. Simulator eksponerer ikke iPhones filbeskyttelsesklasse;
den automatiske testen bekrefter backup-unntak og atomisk cache/anchor, mens
filbeskyttelsesklassen må bekreftes på enheten. Se [pilotgates](health-integration.md).
