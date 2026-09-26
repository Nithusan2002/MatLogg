# Testing

MatLogg bruker risikobasert testing. Datatap, feil ernæringsberegning,
auth/eierskap, synk/idempotens, sletting og personvernvalg prioriteres foran ren
visuell dekning.

## Forutsetninger

- Xcode med en kompatibel iOS-simulator
- Node.js og npm for backend
- Docker når tester krever PostgreSQL
- backend-avhengigheter installert med `npm install` i `backend/`

## iOS

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
lagringsfeil/retry, gjentatte lagretrykk, skjulte verdier, forslag og gjenåpning
av lokal database med tilhørende synkhendelse. `DailyGoalsUITests` dekker
målredigering med omstart, ugyldig input, avbryt, eksplisitt bruk av forslag,
Trygg modus og svært stor tekst. Øvrige kritiske brukerflyter trenger fortsatt
utvidet UI-dekning før release.

Målrettet kjøring for daglige mål (legg til en installert simulator):

```bash
xcodebuild test -project MatLogg.xcodeproj -scheme MatLogg \
  -destination 'platform=iOS Simulator,name=<simulatornavn>' \
  -only-testing:MatLoggTests/DailyGoalsTests \
  -only-testing:MatLoggUITests/DailyGoalsUITests \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO
```

## Backend

Fra `backend/`:

```bash
npm install
npm run build
npm test
```

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
- Safe Mode uten lekkasje gjennom tekst eller tilgjengelighetstre
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
