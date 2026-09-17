# Gjeldende prosjektstatus

Sist kontrollert: 2026-09-16.

Dette dokumentet beskriver hva som finnes i kodebasen nå. Spesifikasjonene
under `docs/specs/` beskriver i tillegg ønsket retning og kan ligge foran
implementasjonen. Kode, Prisma-skjema og migrasjoner er teknisk sannhetskilde.

Midlertidig utviklingsoppsett: Debug-bygg åpner appen med en lokal debug-session
uten innlogging. Launch-argumentet `--show-auth` viser den reelle e-postflyten.
Release-bygg viser alltid autentisering.

## Implementert

### iOS

- SwiftUI-app med fem hovedinnganger: Hjem, Søk, Legg til, Tall og Profil.
- Lokal SQLite-lagring for mål, matlogger, produkter, favoritter,
  skannehistorikk, vekt, produktmatching, Matvaretabellen-cache og synkkø.
- Formell, transaksjonell versjonering av det lokale SQLite-skjemaet via
  `PRAGMA user_version`; eksisterende uversjonerte databaser migreres til v1
  uten å slette domenedata.
- Logging med mengde, måltid, kalorier og makronæringsstoffer.
- Dagsoppsummering og gruppering av logger per måltid.
- Tall-skjerm med dagens energi, sju dagers oversikt, makroer mot mål,
  måltidsfordeling og vektregistrering. Trygg modus skjuler kalorier og mål.
- Strekkodeskanning og produktoppslag mot Open Food Facts.
- Råvaresøk mot Matvaretabellen, med lokal cache.
- Favoritter, nylig brukte produkter og skannehistorikk.
- Persondetaljer, målberegning, vektregistrering og Safe Mode.
- Eksport av brukerdata.
- ViewModels og repository-grenser for sentrale features.
- Minimumsplattform iOS 17. Logging bruker en felles mini-kvittering, globale
  feil presenteres ved app-roten, og standardmåltid velges etter lokal tid.

### Local-first og synk

- Lokale domeneskrivinger oppretter versjonerte synkhendelser.
- Synkkøen støtter pending, in-flight, ack, retry og bounded backoff.
- Hendelsesformatet er dokumentert i `sync-contract-v1.md`.
- Synkmotoren kan sende batcher og behandle bekreftede og avviste hendelser.

### Backend

- NestJS-applikasjon med health-, auth-, Prisma- og sync-moduler.
- E-postregistrering/-innlogging med passordhashing og JWT, samt opt-in
  dev-login for lokal utvikling.
- Autentisert soft-delete av konto, token-revokering og permanent purge etter
  30 dager.
- Autentisert mottak av synkhendelser på `POST /v1/sync/events`.
- Validering av event-type, schema-versjon, batchstørrelse og payload.
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

- `npm run build` og synkkontrakttesten består per 2026-09-16.
- Baseline-migrasjonen og PostgreSQL-integrasjonstesten består lokalt per
  2026-09-16. Testen verifiserer duplikatlevering, eierskapsavvisning og atomisk
  rollback av inbox-innslaget ved avvist domeneskriving.
- Den autentiserte HTTP-integrasjonstesten består lokalt. Den verifiserer JWT,
  401 uten token, delvis avvist batch, trygg replay etter tapt ACK og at avviste
  domeneskrivinger ikke etterlater inbox-data.
- iOS-testen for køgjenoppretting består: en `inFlight`-hendelse i en lukket
  SQLite-database kommer tilbake som `pending` med samme event-ID, payload og
  forsøksteller når databasen åpnes på nytt.
- Full iOS–server-flyt er fortsatt ikke verifisert. Løsningen er derfor ikke
  releaseklar.

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

1. Verifiser kompatibilitet mellom aktuell iOS-klient og backend ende til ende.
2. Hold `backendSyncEnabled` avslått til denne flyten og øvrige releaseporter er
   grønne.

Oppdater dette dokumentet når en funksjon flyttes mellom planlagt, delvis
implementert og implementert.
