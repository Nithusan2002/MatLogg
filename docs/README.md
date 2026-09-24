# MatLogg-dokumentasjon

Dette er inngangen til prosjektets produkt- og tekniske grunnlag. Dokumentene beskriver ønsket retning; gjeldende kode, Prisma-skjema og migrasjoner er teknisk sannhetskilde.

Start produkt- og designarbeid med [produktbriefen](product-brief.md),
[design- og brukerflyten](design-and-user-flow.md) og
[designsystemet](design-system.md). Disse er de overordnede, normative kildene;
filene under `specs/` utdyper krav og historikk og skal oppdateres ved konflikt.

Start tekniske endringer med [arkitekturprinsippene](architecture-principles.md). For synk gjelder også [synkkontrakt v1](sync-contract-v1.md).

Funksjonsscope for gjenbruk finnes i [gårsdagens måltid](meal-reuse.md) og
[lagrede måltider](saved-meals.md).

For å skille faktisk implementasjon fra planlagt scope, start med
[gjeldende prosjektstatus](current-state.md). Kommandoer og kvalitetskrav finnes
i [testveiledningen](testing.md).

## Leserekkefølge

1. [Produktbrief](product-brief.md)
2. [Design- og brukerflyt](design-and-user-flow.md)
3. [Designsystem](design-system.md)
4. [MVP-scope](specs/01-mvp-scope.md)
5. [Brukerhistorier og detaljerte flyter](specs/02-user-stories-flows.md)
6. [Wireframes og skjermreferanser](specs/03-wireframes-screens.md)
7. [Mikrointeraksjoner](specs/04-microinteractions.md)
8. [Datamodell og synk](specs/05-data-model-sync.md)
9. [API-endepunkter](specs/06-api-endpoints.md)
10. [Edge cases](specs/07-edge-cases.md)
11. [Roadmap](specs/08-roadmap.md)
12. [Risiko og tiltak](specs/09-risks-mitigation.md)

## Praktiske sannhetskilder

- Implementert/delvis/planlagt status: [gjeldende prosjektstatus](current-state.md)
- Build, test og release-gates: [testveiledningen](testing.md)
- iOS-oppstart og dependency composition: `MatLogg/MatLoggApp.swift` og `MatLogg/App/AppState.swift`
- Lokal lagring og synkkø: `MatLogg/Services/LocalStore.swift` og `MatLogg/Services/SyncEngine.swift`
- API-klient: `MatLogg/Services/APIService.swift`
- Backend-kontrakt: `backend/src/`
- Persistensmodell: `backend/prisma/schema.prisma`
- Lokal backend-oppskrift: `backend/README.md`
- Varige prosjektvalg: [beslutningslogg](decisions.md)
- Produktets hensikt og avgrensning: [produktbrief](product-brief.md)
- Gjeldende UX-retning og hovedflyter: [design- og brukerflyt](design-and-user-flow.md)
- Visuelle regler og komponentbruk: [designsystem](design-system.md)
- Normative arkitekturkrav: [arkitekturprinsipper](architecture-principles.md)
- Gjeldende synkformat: [synkkontrakt v1](sync-contract-v1.md)

Når implementasjonen bevisst avviker fra en spesifikasjon, oppdater dokumentet eller noter beslutningen i samme endring.

`specs/06-api-endpoints.md` beskriver også planlagte endepunkter. Et endepunkt
regnes ikke som implementert før det finnes i `backend/src/` og er verifisert.
