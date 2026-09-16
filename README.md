# MatLogg

MatLogg er en norsk iOS-app for rask matlogging, ernæringsoversikt og
måloppfølging. SwiftUI-klienten er local-first: brukerhandlinger lagres i
SQLite før eventuell synk mot NestJS/PostgreSQL-backenden.

## Status

Prosjektet er under aktiv MVP-utvikling og er ikke produksjonsklart.

- Matlogging, dagsoversikt, favoritter, historikk, vekt og ernæringsmål lagres
  lokalt.
- Produkter kan finnes via strekkode/Open Food Facts og råvaresøk i
  Matvaretabellen.
- En versjonert synkkø, retry/backoff og backend-mottak finnes, men
  `FeatureFlags.backendSyncEnabled` er avslått.
- Backend tilbyr foreløpig health check, dev-login og mottak av synkhendelser.
- Debug-build hopper over ordinær innlogging og bruker en utviklingssesjon.

Se [gjeldende prosjektstatus](docs/current-state.md) for implementert, delvis
implementert og planlagt funksjonalitet.

## Arkitektur

iOS-klienten følger pragmatisk MVVM:

```text
View → ViewModel → Repository → Service / LocalStore / API
```

Viktige prinsipper:

- logging skal fungere uten nett
- domenedata og synkhendelse skrives atomisk lokalt
- synkhendelser har stabil event-ID, canonical type og schema-versjon
- identitet og eierskap valideres på backend
- ernæringskilde og måleenhet skal bevares

Les [arkitekturprinsippene](docs/architecture-principles.md) og
[synkkontrakt v1](docs/sync-contract-v1.md) før relevante endringer.

## Prosjektstruktur

```text
MatLogg/                 SwiftUI-app
  App/                   Modeller, appkoordinering og feature flags
  DesignSystem/          Semantiske tokens og delte komponenter
  Services/              Lokal lagring, repositories, API, auth og synk
  ViewModels/            Feature-state og brukerhandlinger
  Views/                 Feature-sorterte skjermer
MatLoggTests/            iOS-enhets- og integrasjonstester
MatLoggUITests/          iOS UI-tester
backend/                 NestJS, Prisma og PostgreSQL
docs/                    Produkt- og teknisk dokumentasjon
matlogg-legal/           Juridiske tekster
.agents/skills/          Prosjektspesifikke agentarbeidsflyter
```

## Lokal oppstart

### iOS

Krav: en kompatibel versjon av Xcode og en installert iOS-simulator.

1. Åpne `MatLogg.xcodeproj`.
2. Velg `MatLogg`-scheme og en simulator.
3. Bygg og kjør appen.

### Backend

Krav: Node.js, npm og Docker.

```bash
cd backend
docker compose up -d
npm install
npx prisma migrate dev
npm run start:dev
```

Backend kjører som standard på `http://localhost:4000`. Se
[backendens README](backend/README.md) for health check, Swagger og dev-login.

## Testing

Se [testveiledningen](docs/testing.md) for kommandoer, testnivåer og krav før
synk eller release.

## Dokumentasjon

[Dokumentasjonsindeksen](docs/README.md) peker til MVP-scope, brukerflyter,
datamodell, API-målbilde, roadmap, risikoer og tekniske sannhetskilder.

Prosjektet er privat.
