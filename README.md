# Spor Mat (tidligere MatLogg)

MatLogg videreføres som Spor Mat. Dette er det samme prosjektet som tidligere er omtalt som MatLogg i søknader og prosjektbeskrivelser.

Repoet beholder navnet `MatLogg`, slik at eksisterende GitHub-lenker fungerer videre. Tekniske navn og filstier beholdes også.

Spor Mat er en norsk iOS-app for rask matlogging, ernæringsoversikt og
måloppfølging. SwiftUI-klienten er local-first: brukerhandlinger lagres i
SQLite. Første lansering bruker bare lokale domenedata, uten skybackup eller
flerenhetssynk. Supabase brukes til valgfri konto (Auth); Edge Functions og
PostgreSQL er bevart for framtidig synk.
NestJS/Prisma-backenden beholdes som legacy under cutover.

## Status

Prosjektet er under aktiv MVP-utvikling og er ikke produksjonsklart.
Intern TestFlight-testing er dokumentert; dette er ikke en samlet godkjenning
av ekstern pilot eller produksjon. Se [produksjonsberedskap](docs/production-readiness.md).

- Matlogging, dagsoversikt, favoritter, historikk, vekt og ernæringsmål lagres
  lokalt.
- Produkter kan finnes via strekkode/Open Food Facts og råvaresøk i
  Matvaretabellen.
- En versjonert synkkø, retry/backoff og backend-mottak finnes, men
  `DomainUploadPolicy.localOnly` sperrer opplasting og retry-timere uavhengig
  av backendflagget. `FeatureFlags.backendSyncEnabled` er også avslått.
- Supabase-konto er tilgjengelig når appkonfigurasjon finnes; uten den
  fungerer lokal profil fortsatt, mens kontokall er utilgjengelige.
  Kontokobling åpner ikke opplasting.
- Vannlogging, lagrede måltider, lokale produktbilder og DEBUG-demomodus finnes.
- Utvikling viser mat og næring, skritt, vekt og treningsøkter for dag, uke
  og måned, med lokale valg for synlige kort. Valgfri tilkobling til Apple
  Helse for skritt, vekt og treningsøkter styres under Profil → Innstillinger.
- Førstegangsbruk oppretter lokal profil automatisk og åpner første logging
  direkte. Innlogging er valgfri. `--skip-auth` aktiverer en lokal
  utviklingssesjon bare i DEBUG.

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

Krav: Xcode med støtte for valgt kjøreenhet. Appen krever iOS 17 eller nyere
og kan kjøres på fysisk iPhone eller en installert iOS-simulator.

1. Åpne `MatLogg.xcodeproj`.
2. Velg `MatLogg`-scheme og en iPhone eller simulator. Fysisk iPhone krever
   konfigurert kodesignering i Xcode.
3. Bygg og kjør appen.

Lokal matlogging krever verken konto eller et kjørende Supabase-miljø.

### Supabase

Valgfritt for arbeid med kontotjenester og backend. Krav: Docker og Node.js.
Fra repo-roten:

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
