# AGENTS.md – MatLogg

## Prosjekt

MatLogg er en norsk iOS-app for enkel matlogging, ernæringsoversikt og måloppfølging. Klienten er SwiftUI og local-first; backend er NestJS med Prisma/PostgreSQL og mottar idempotente synkhendelser.

Les `docs/README.md` og relevante spesifikasjoner før produktmessige eller arkitektoniske endringer. Kode og migrasjoner er teknisk sannhetskilde når eldre spesifikasjoner avviker; dokumenter viktige avvik.

## Grunnregler

- Bygg den enkleste løsningen som dekker avtalt scope. Ikke utvid MVP uten å synliggjøre konsekvensene.
- Bevar local-first: brukerens logging skal fungere uten nett, og synk skal være idempotent og tåle retry.
- Behandle ernæringsverdier, målberegninger og brukerdata som sensitive. Ikke presenter estimater som medisinske råd eller dokumenterte fakta.
- Bevar datakilde og måleenhet gjennom søk, matching, lagring og visning. Ikke gjett manglende næringsdata.
- Legg aldri hemmeligheter, tokens, persondata eller ekte produksjonsdata i repoet.
- Bruk Prisma-migrasjoner for skjemaendringer. Ikke rediger genererte filer i `backend/dist/`.
- Bruk semantiske design-tokens og eksisterende komponenter fremfor lokale stilvarianter.
- Hold `AppState` som koordinering, ikke som permanent hjem for ny domenelogikk eller IO.
- Kjør tester og bygg ut fra risiko. Oppgi alltid hva som ble kjørt, eller hvorfor verifisering ble hoppet over.
- Oppdater relevante docs når API-kontrakter, synkformat eller scope endres. Før større tekniske og produktmessige beslutninger i `docs/decisions.md`.

## Prosjektkart

| Område | Formål |
| --- | --- |
| `MatLogg/App/` | App-state, domenemodeller, feature flags og personvernkonstanter |
| `MatLogg/DesignSystem/` | Farger, typografi og gjenbrukbare SwiftUI-komponenter |
| `MatLogg/Services/` | Lokal lagring, API, auth, synk, matching og enhetsintegrasjoner |
| `MatLogg/Views/` | Feature-sorterte skjermer og delte views |
| `MatLoggTests/`, `MatLoggUITests/` | Swift Testing og UI-tester |
| `backend/src/` | NestJS-moduler for auth, helse, Prisma og synk |
| `backend/prisma/` | Databaseskjema og migrasjoner |
| `docs/specs/` | Produkt-, UX-, data-, API- og roadmap-spesifikasjoner |
| `docs/decisions.md` | Kort, kronologisk logg over varige tekniske og produktmessige valg |
| `matlogg-legal/` | Juridiske tekster; endres med særskilt varsomhet |

## Skills

Bruk relevante skills fra `.agents/skills/` for arbeidsområdet.

| Arbeid | Påkrevd skill |
| --- | --- |
| Ny funksjon, endret scope eller større brukerflyt | `product-review` før implementering |
| SwiftUI, navigasjon, state, design system, tilgjengelighet eller iOS-tester | `ios-swiftui` |
| Lokal lagring, event queue, konfliktregler eller synkformat | `offline-sync` |
| NestJS, Prisma, auth, API-kontrakter eller databaseendringer | `backend-api` |
| Ernæringsdata, måleenheter, målberegning, personvern eller helserelatert språk | `nutrition-privacy` |
| Nye funksjoner, sikkerhetskritiske endringer, pilot eller release | `qa-release` etter relevante fag-skills |

`nutrition-privacy` er obligatorisk for endringer som påvirker kalorimål, vekt, personopplysninger eller kildevisning. `qa-release` er obligatorisk før produksjonsutrulling.

## Arbeidsrekkefølge

- Ny brukerfunksjon: produktvurdering → iOS/UX → backend/synk ved behov → implementering → QA.
- Data- eller synkendring: offline-sync → backend-api → kompatibilitetsvurdering → implementering → QA.
- Release: relevante fag-skills → qa-release → eksplisitt go/no-go.

## Stopp før

Forklar konsekvensene og be om avklaring før destruktive datamigrasjoner, sletting av vesentlig kode eller brukerdata, endringer i autentisering/tilgang, håndtering av produksjonshemmeligheter, produksjonsutrulling eller større avvik fra spesifisert scope.

## Ferdigdefinisjon

Rapporter kort: hva som ble endret, berørte filer, skills brukt, verifisering, antakelser og gjenværende risiko eller neste steg.
