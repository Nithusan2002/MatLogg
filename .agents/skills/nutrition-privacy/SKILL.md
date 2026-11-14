---
name: nutrition-privacy
description: Kontroller MatLogg-endringer som berører ernæringsdata, enheter, matvarekilder, målberegning, vekt, personvern eller helserelatert brukerkommunikasjon.
---

# Ernæringsdata og personvern

Les relevant del av `docs/specs/05-data-model-sync.md`, `docs/specs/09-risks-mitigation.md`, `matlogg-legal/privacy.md` og berørt kode.

Bevar råverdi, enhet, porsjonsgrunnlag og kilde så langt datamodellen tillater. Skill dokumenterte verdier fra beregnede eller estimerte verdier, og ikke fyll manglende næringsstoffer med antatte tall. Avrunding skal skje ved visning med mindre kontrakten krever annet.

Kalori- og makromål er veiledende produktberegninger, ikke diagnose eller behandling. Vurder urealistiske input, trygge grenser, spiseforstyrrelsessensitivt språk og Safe Mode. Ikke bruk skam, absolutte helseløfter eller manipulerende målbudskap.

Minimer innsamling og logging av person-, helse- og vektdata. Sjekk formål, samtykke, lokal/ekstern lagring, sletting, eksport og tredjepartsdeling. Endringer i faktisk databruk må gjenspeiles i brukergrensesnitt og juridisk tekst før release.

Apple Helse brukes i dagens Release-scope bare til valgfri visning av skritt, vekt og treningsøkter i Utvikling. Målingene holdes midlertidig i minnet, uten vedvarende lagring eller opplasting, og inngår ikke i målberegning, eksport, analyse eller logger. Tilkoblingsvalg lagres lokalt per profil; skill disse innstillingene fra selve Helse-dataene. Kontroller endringer mot `matlogg-legal/privacy.md` og berørte Health-repositories/ViewModels. Utvidet databruk er en scope-endring som krever egen produkt- og personvernvurdering før implementering.


Godkjent utviklingsscope fra 2026-11-14 omfatter Debug-gatet eksport av egne
matlogger (kalorier/makroer) og manuell vekt. Se `docs/decisions.md` og
`docs/design-and-user-flow.md`. Bevar opt-in per profil/datagruppe, ingen
automatisk historikkeksport, atomisk lokal outbox og stabil identitet/revisjon
ved retry/redigering/sletting. Eksport må ikke kopiere Helse-leste målinger til
domenelagring eller server. Før Release kreves fysisk QA og egen go/no-go.
