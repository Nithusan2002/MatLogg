# MatLogg-dokumentasjon

Dette er inngangen til prosjektets produkt- og tekniske grunnlag. Dokumentene beskriver ønsket retning; gjeldende kode, Prisma-skjema og migrasjoner er teknisk sannhetskilde.

Start tekniske endringer med [arkitekturprinsippene](architecture-principles.md). For synk gjelder også [synkkontrakt v1](sync-contract-v1.md).

For å skille faktisk implementasjon fra planlagt scope, start med
[gjeldende prosjektstatus](current-state.md). Kommandoer og kvalitetskrav finnes
i [testveiledningen](testing.md).

## Leserekkefølge

1. [MVP-scope](specs/01-mvp-scope.md)
2. [Brukerhistorier og flyter](specs/02-user-stories-flows.md)
3. [Wireframes og skjermer](specs/03-wireframes-screens.md)
4. [Mikrointeraksjoner](specs/04-microinteractions.md)
5. [Datamodell og synk](specs/05-data-model-sync.md)
6. [API-endepunkter](specs/06-api-endpoints.md)
7. [Edge cases](specs/07-edge-cases.md)
8. [Roadmap](specs/08-roadmap.md)
9. [Risiko og tiltak](specs/09-risks-mitigation.md)

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
- Normative arkitekturkrav: [arkitekturprinsipper](architecture-principles.md)
- Gjeldende synkformat: [synkkontrakt v1](sync-contract-v1.md)

Når implementasjonen bevisst avviker fra en spesifikasjon, oppdater dokumentet eller noter beslutningen i samme endring.

`specs/06-api-endpoints.md` beskriver også planlagte endepunkter. Et endepunkt
regnes ikke som implementert før det finnes i `backend/src/` og er verifisert.
