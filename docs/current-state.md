# Gjeldende prosjektstatus

Sist kontrollert: 2026-09-26.

Dette dokumentet beskriver hva som finnes i kodebasen nå. Spesifikasjonene
under `docs/specs/` beskriver i tillegg ønsket retning og kan ligge foran
implementasjonen. Kode, Prisma-skjema og migrasjoner er teknisk sannhetskilde.

Midlertidig utviklingsoppsett: Debug-bygg åpner appen med en lokal debug-session
uten innlogging. Launch-argumentet `--show-auth` viser den reelle e-postflyten.
Release-bygg viser alltid autentisering.

## Implementert

### iOS

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
- Formell, transaksjonell versjonering av det lokale SQLite-skjemaet via
  `PRAGMA user_version`; eksisterende uversjonerte databaser migreres til v1
  uten å slette domenedata.
- Feil ved åpning eller migrering beholder databasefilen urørt og viser en
  blokkerende feiltilstand i stedet for å krasje eller starte med et tomt lager.
  Uleselige JSON-rader logges diagnostisk uten å bli slettet.
- Logging med mengde og bevart enhet (`g`/`ml`), måltid, kalorier og
  makronæringsstoffer. Eldre data uten enhet tolkes som gram.
- Dagsnavigasjon med piler og kalender på Hjem og i Logg. Valgt dato følger
  dagsoppsummering, måltidsliste og nye registreringer, også for fremtidige
  datoer.
- Dagsoppsummering og gruppering av logger per måltid.
- Tall-skjerm med dagens energi, sju dagers oversikt, makroer mot mål,
  måltidsfordeling og vektregistrering. Trygg modus skjuler kalorier og mål.
- Strekkodeskanning og produktoppslag mot Open Food Facts API v3. Gyldige treff
  får stabil identitet fra kilde + strekkode og caches lokalt uten å opprette
  `product.upsert`-hendelser. Dokumenterte væskemengder og næringsgrunnlag per
  100 ml bevares som milliliter uten å gjette tetthet eller konvertere til gram.
- Cachede Open Food Facts-produkter brukes uten nettverkskall i 30 dager. Eldre
  treff vises fortsatt umiddelbart og revalideres én gang per strekkode i
  bakgrunnen; ved feil beholdes snapshotet og nytt forsøk utsettes i 24 timer.
- Kombinert matsøk: råvarer fra Matvaretabellen med lokal cache og navnesøk etter
  merkevarer i Open Food Facts. Eksterne treff uten komplett kcal-/makrogrunnlag
  vises ikke, fordi manglende næringsverdier ikke skal gjettes som null.
- Open Food Facts-kall bruker identifiserende app-/kontakt-header og kort
  nettverkstimeout, og 429-svar bevarer eventuell `Retry-After`. Også
  strekkodetreff uten komplett kcal-/makrogrunnlag avvises fremfor å fylle
  manglende verdier med null. Navnesøk sendes bare eksplisitt med Søk-knappen
  eller tastaturets søkehandling, ikke fortløpende per tastetrykk.
- Backend- og katalogkall bruker en felles transportgrense med eksplisitt
  timeout og egne feil for offline, timeout og brutt forbindelse.
  Matvaretabellen validerer nå HTTP-status i stedet for å tolke 429/5xx som
  tomme søkeresultater. Idempotente katalogoppslag retries høyst én gang.
- Favoritter, nylig brukte produkter og skannehistorikk.
- Persondetaljer, målberegning, vektregistrering og Safe Mode.
- Personlige målforslag er avgrenset til voksne med komplett, støttet
  beregningsgrunnlag. Appen gjetter ikke et generelt kaloriforslag når grunnlaget
  mangler, og standard makroprofiler ligger innenfor NNR 2023-intervallene.
- Egen redigeringsskjerm for daglige mål med utkast, feltvalidering, eksplisitt
  godkjenning av nye beregningsforslag og lagringsfeil som bevarer input.
  Skjermen følger separate visningsvalg for kalorier og mål.
- Eksport av brukerdata.
- ViewModels og repository-grenser for sentrale features.
- Minimumsplattform iOS 17. Logging bruker en kompakt, ikke-modal bekreftelse
  med angre; globale feil presenteres ved app-roten, og standardmåltid velges
  etter lokal tid.

### Local-first og synk

- Lokale domeneskrivinger oppretter versjonerte synkhendelser.
- Synkkøen støtter pending, in-flight, ack, retry, dead-letter og bounded
  backoff. Køen vekkes ved `nextRetryAt` og når nettforbindelsen kommer tilbake;
  permanent avviste hendelser beholdes for manuelt nytt forsøk.
- Hendelsesformatet er dokumentert i `sync-contract-v1.md`.
- Synkmotoren kan sende batcher og behandle bekreftede og avviste hendelser.

### Backend

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

## Delvis implementert eller deaktivert

- `FeatureFlags.backendSyncEnabled` er `false`. Produksjonssynk er derfor
  deaktivert selv om klient- og backendkomponenter finnes.
- `FeatureFlags.goalCalibrationEnabled` er `false`.
- Debug-sesjon aktiveres bare eksplisitt med launch-argumentet `--debug-auth`.
- Apple- og Google-innlogging er senere scope og vises ikke i klienten.
- Manuell opprettelse av ukjente produkter finnes fra skanneflyten.
- Backend dekker ikke alle endepunktene i `specs/06-api-endpoints.md`.
  API-spesifikasjonen er derfor et målbilde med mindre kode viser noe annet.

## Ikke dokumentert som produksjonsklart

- Produksjonsmiljø, deploy og rollback.
- Overvåkning, alarmer og operativ hendelseshåndtering.
- Backup- og restore-prosedyre for PostgreSQL.
- Full kontrakt-, retry-, idempotens-, eierskaps- og integrasjonstestdekning.
- App Store-klargjøring og eksplisitt release-godkjenning.
- Verifisert samsvar mellom faktisk databruk, samtykke og juridisk tekst.

## Gjeldende verifiseringsstatus

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
| Klientsynk | `MatLogg/Services/SyncEngine.swift` og `APIService.swift` |
| Synkformat | `docs/sync-contract-v1.md` og `backend/src/sync/` |
| Backend-datamodell | `backend/prisma/schema.prisma` og `backend/prisma/migrations/` |
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
  består. Auth-integrasjonstesten er utvidet med rotasjon og gjenbruksvern, men
  kunne ikke kjøres i kontrollmiljøet fordi PostgreSQL/Docker ikke var
  tilgjengelig. Produksjonssynk forblir derfor deaktivert.

### Daglige mål – verifisert 2026-09-21

- Appen bygger for iOS Simulator. `DailyGoalsTests` og `PreferencesViewModelTests`
  består (15 testfunksjoner, med flere parameteriserte tilfeller).
- Seks målrettede UI-tester har bestått på iPhone 17 Pro / iOS 26.5 i separate
  kjøringer: redigering og omstart, ugyldig input og avbryt, forslag som utkast,
  svært stor tekst, skjulte kalorier og Trygg modus.
- UI-testene for visningsvalg setter preferanser ved appstart. Betjening av
  bryterne i Innstillinger ble ikke bekreftet av denne testkjøringen.
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
