---
name: nutrition-privacy
description: Kontroller MatLogg-endringer som berører ernæringsdata, enheter, matvarekilder, målberegning, vekt, personvern eller helserelatert brukerkommunikasjon.
---

# Ernæringsdata og personvern

Les relevant del av `docs/specs/05-data-model-sync.md`, `docs/specs/09-risks-mitigation.md`, `matlogg-legal/privacy.md` og berørt kode.

Bevar råverdi, enhet, porsjonsgrunnlag og kilde så langt datamodellen tillater. Skill dokumenterte verdier fra beregnede eller estimerte verdier, og ikke fyll manglende næringsstoffer med antatte tall. Avrunding skal skje ved visning med mindre kontrakten krever annet.

Kalori- og makromål er veiledende produktberegninger, ikke diagnose eller behandling. Vurder urealistiske input, trygge grenser, spiseforstyrrelsessensitivt språk og Safe Mode. Ikke bruk skam, absolutte helseløfter eller manipulerende målbudskap.

Minimer innsamling og logging av person-, helse- og vektdata. Sjekk formål, samtykke, lokal/ekstern lagring, sletting, eksport og tredjepartsdeling. Endringer i faktisk databruk må gjenspeiles i brukergrensesnitt og juridisk tekst før release.

## Apple Helse

Skill mellom lesing fra Helse og eksport av egne registreringer:

- Leste skritt, vekt og treningsøkter holdes midlertidig i minnet. De skal ikke kopieres til domenelagring, server, eksport, målberegning, analyse eller logger. Tilkoblingsvalg lagres lokalt per profil og er ikke selve Helse-målingene.
- Release har valgfri eksport av egne matlogger (kalorier/makroer) og manuelt registrert vekt. Debug krever `--enable-healthkit-export`. Bevar eksplisitt opt-in per profil/datagruppe, atomisk lokal outbox og stabil identitet/revisjon ved retry, redigering og sletting.
- Aktivering av deling skal ikke eksportere historikk automatisk. Tidligere registreringer deles bare etter eksplisitt periodevalg, forhåndsvisning og bekreftelse for valgt profil og aktive datagrupper.

Kontroller gjeldende scope og QA-status i relevante deler av `docs/current-state.md`, `docs/decisions.md`, `docs/testing.md`, `matlogg-legal/privacy.md` og berørte Health-repositories/ViewModels. Historisk godkjenning er ikke releasegodkjenning av en ny kandidat. Utvidet databruk krever egen produkt- og personvernvurdering før implementering.
