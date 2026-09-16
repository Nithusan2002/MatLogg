# Gjeldende prosjektstatus

Sist kontrollert: 2026-09-16.

Dette dokumentet beskriver hva som finnes i kodebasen nå. Spesifikasjonene
under `docs/specs/` beskriver i tillegg ønsket retning og kan ligge foran
implementasjonen. Kode, Prisma-skjema og migrasjoner er teknisk sannhetskilde.

## Implementert

### iOS

- SwiftUI-app med fem hovedinnganger: Hjem, Søk, Legg til, Fremgang og Profil.
- Lokal SQLite-lagring for mål, matlogger, produkter, favoritter,
  skannehistorikk, vekt, produktmatching, Matvaretabellen-cache og synkkø.
- Logging med mengde, måltid, kalorier og makronæringsstoffer.
- Dagsoppsummering og gruppering av logger per måltid.
- Strekkodeskanning og produktoppslag mot Open Food Facts.
- Råvaresøk mot Matvaretabellen, med lokal cache.
- Favoritter, nylig brukte produkter og skannehistorikk.
- Persondetaljer, målberegning, vektregistrering og Safe Mode.
- Eksport av brukerdata.
- ViewModels og repository-grenser for sentrale features.

### Local-first og synk

- Lokale domeneskrivinger oppretter versjonerte synkhendelser.
- Synkkøen støtter pending, in-flight, ack, retry og bounded backoff.
- Hendelsesformatet er dokumentert i `sync-contract-v1.md`.
- Synkmotoren kan sende batcher og behandle bekreftede og avviste hendelser.

### Backend

- NestJS-applikasjon med health-, auth-, Prisma- og sync-moduler.
- Dev-login med JWT for lokal utvikling.
- Autentisert mottak av synkhendelser på `POST /v1/sync/events`.
- Validering av event-type, schema-versjon, batchstørrelse og payload.
- Prisma/PostgreSQL-modell for synk-inbox og relevante domenedata.
- Kontrakttest for sentrale synkgrenser og payload-skjemaer.

## Delvis implementert eller deaktivert

- `FeatureFlags.backendSyncEnabled` er `false`. Produksjonssynk er derfor
  deaktivert selv om klient- og backendkomponenter finnes.
- `FeatureFlags.goalCalibrationEnabled` er `false`.
- Debug-build hopper over ordinær innlogging og oppretter en utviklingssesjon.
- Ordinære auth-flyter finnes i klienten, men må verifiseres ende til ende mot
  et reelt miljø før de regnes som releaseklare.
- Manuell opprettelse av produkt er synlig som planlagt handling enkelte steder,
  men full flyt er ikke ferdig.
- Backend dekker ikke alle endepunktene i `specs/06-api-endpoints.md`.
  API-spesifikasjonen er derfor et målbilde med mindre kode viser noe annet.

## Ikke dokumentert som produksjonsklart

- Produksjonsmiljø, deploy og rollback.
- Overvåkning, alarmer og operativ hendelseshåndtering.
- Backup- og restore-prosedyre for PostgreSQL.
- Full kontrakt-, retry-, idempotens-, eierskaps- og integrasjonstestdekning.
- App Store-klargjøring og eksplisitt release-godkjenning.
- Verifisert samsvar mellom faktisk databruk, samtykke og juridisk tekst.

## Kjente verifiseringsfeil

- `npm run build` feiler per 2026-09-16 med TypeScript-typer rundt Prisma:
  `beforeExit` i `prisma.service.ts` og transaksjonsklienten som sendes til
  `applyEvent` i `sync.service.ts`. Synkkontrakttesten består separat, men
  backend kan ikke regnes som byggbar før begge feilene er rettet.

## Aktive tekniske sannhetskilder

| Tema | Sannhetskilde |
| --- | --- |
| App-sammensetting | `MatLogg/MatLoggApp.swift` |
| Feature flags | `MatLogg/App/FeatureFlags.swift` |
| Lokal lagring og skjema | `MatLogg/Services/LocalStore.swift` |
| Klientsynk | `MatLogg/Services/SyncEngine.swift` og `APIService.swift` |
| Synkformat | `docs/sync-contract-v1.md` og `backend/src/sync/` |
| Backend-datamodell | `backend/prisma/schema.prisma` |
| Varige valg | `docs/decisions.md` |

## Nærmeste tekniske milepæl

Før backend-synk aktiveres:

1. Test kontrakt og domeneskriving ende til ende mot PostgreSQL.
2. Verifiser retry etter timeout og prosessavbrudd.
3. Verifiser deduplisering ved gjentatt `eventId`.
4. Verifiser at autentisert bruker ikke kan skrive til en annen brukers data.
5. Verifiser kompatibilitet mellom aktuell klient og backend.
6. Hold `backendSyncEnabled` avslått til alle punktene er grønne.

Oppdater dette dokumentet når en funksjon flyttes mellom planlagt, delvis
implementert og implementert.
