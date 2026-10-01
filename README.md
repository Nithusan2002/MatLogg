# MatLogg

MatLogg er en norsk iOS-app for rask matlogging, ernæringsoversikt og
måloppfølging. SwiftUI-klienten er local-first: brukerhandlinger lagres i
SQLite før eventuell synk mot Supabase (Auth, Edge Functions og PostgreSQL).
NestJS/Prisma-backenden beholdes som legacy under cutover.

## Status

Prosjektet er under aktiv MVP-utvikling og er ikke produksjonsklart.

- Matlogging, dagsoversikt, favoritter, historikk, vekt og ernæringsmål lagres
  lokalt.
- Produkter kan finnes via strekkode/Open Food Facts og råvaresøk i
  Matvaretabellen.
- En versjonert synkkø, retry/backoff og backend-mottak finnes, men
  `FeatureFlags.backendSyncEnabled` er avslått.
- Supabase er koblet til konto og synk når appkonfigurasjon finnes; uten den
  fungerer lokal profil fortsatt, mens kontokall er utilgjengelige.
- Vannlogging, lagrede måltider, lokale produktbilder og DEBUG-demomodus finnes.
- Debug bruker ordinær innloggingsflyt som standard. `--skip-auth` aktiverer
  en lokal utviklingssesjon.

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
supabase/                Aktiv serverplattform: migrasjoner, RLS og Edge Functions
backend/                 Legacy NestJS/Prisma under cutover
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

### Supabase

Krav: Docker og Node.js. Fra repo-roten:

```bash
npm ci
npm run supabase:start
npm run supabase:reset
```

Se [Supabase-oppsettet](supabase/README.md) for lokal appkonfigurasjon,
verifisering, staging og kill switch. Synk er avslått som standard.

### Legacy-backend

NestJS er bevart for historikk og kompatibilitetskontroll, og er ikke appens
aktive konto-/synkplattform. Se [legacy-backendens README](backend/README.md)
ved arbeid i `backend/`.

## Testing

Se [testveiledningen](docs/testing.md) for kommandoer, testnivåer og krav før
synk eller release.

## Dokumentasjon

[Dokumentasjonsindeksen](docs/README.md) peker til MVP-scope, brukerflyter,
datamodell, API-målbilde, roadmap, risikoer og tekniske sannhetskilder.

Repoet er offentlig tilgjengelig med en proprietær
[«All rights reserved»-lisens](LICENSE). Offentlig visning gir ikke tillatelse
til gjenbruk; se lisensvilkårene.
