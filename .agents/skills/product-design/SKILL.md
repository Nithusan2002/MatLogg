---
name: product-design
description: Utform og vurder MatLoggs visuelle retning, informasjonsarkitektur, brukerflyter, UX-tekst og designsystem før SwiftUI-implementering.
---

# Produktdesign

Start med relevante deler av `docs/product-brief.md`, `docs/design-and-user-flow.md` og `docs/design-system.md`. Disse er normative for produkt og design. Bruk relevante deler av `docs/specs/02-user-stories-flows.md`, `docs/specs/03-wireframes-screens.md` og `docs/specs/04-microinteractions.md` som utdyping og historikk. Les berørte filer under `MatLogg/DesignSystem/` og berørte views for å skille dokumentert intensjon fra faktisk implementasjon. Ved konflikt, følg de normative dokumentene og samordne berørt spesifikasjon; kode viser hva som faktisk er implementert.

## Prinsipper

- Prioriter rask og rolig matlogging: primærhandlingen skal være tydelig, informasjonsmengden begrenset og neste steg forutsigbart.
- Bruk Apple-plattformmønstre og eksisterende semantiske tokens før nye visuelle konsepter introduseres.
- Bevar konsistens i hierarki, spacing, hjørner, ikonbruk, kontrolltyper, tilstander og norsk terminologi på tvers av skjermer.
- Design loading, tom, offline, feil, suksess, deaktivert og ekstreme datatilstander sammen med normaltilstanden.
- Ernæringsstatus skal informere uten skam eller alarmisme. Safe Mode, kildevisning og redusert fokus på kalorier skal fungere som sammenhengende designvalg.
- Tilgjengelighet er en del av designet: Dynamic Type, kontrast, VoiceOver-rekkefølge, minimum touchflate, redusert bevegelse og informasjon som ikke bæres av farge alene.

## Leveranse

Ved nytt eller endret design, lever:

1. brukerbehov og berørt flyt
2. informasjons- og handlingshierarki
3. skjermtilstander og viktige interaksjoner
4. gjenbrukte og eventuelt nye design-tokens eller komponenter
5. kort UX-tekst på norsk
6. tilgjengelighetskrav og konkrete akseptansekriterier

Skill mellom designbeslutning og implementasjonsdetalj. Bruk `ios-swiftui` når designet skal bygges eller kodegjennomgås. Oppdater relevante designspesifikasjoner når en varig retning endres.
