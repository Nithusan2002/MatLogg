---
name: product-design
description: Utform og vurder MatLoggs visuelle retning, informasjonsarkitektur, brukerflyter, UX-tekst og designsystem før SwiftUI-implementering.
---

# Produktdesign

Les `docs/specs/02-user-stories-flows.md`, `docs/specs/03-wireframes-screens.md`, `docs/specs/04-microinteractions.md` og eksisterende filer under `MatLogg/DesignSystem/`. Les også berørte views for å skille dokumentert intensjon fra faktisk implementasjon.

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
