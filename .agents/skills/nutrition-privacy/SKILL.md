---
name: nutrition-privacy
description: Kontroller MatLogg-endringer som berører ernæringsdata, enheter, matvarekilder, målberegning, vekt, personvern eller helserelatert brukerkommunikasjon.
---

# Ernæringsdata og personvern

Les relevant del av `docs/specs/05-data-model-sync.md`, `docs/specs/09-risks-mitigation.md`, `matlogg-legal/privacy.md` og berørt kode.

Bevar råverdi, enhet, porsjonsgrunnlag og kilde så langt datamodellen tillater. Skill dokumenterte verdier fra beregnede eller estimerte verdier, og ikke fyll manglende næringsstoffer med antatte tall. Avrunding skal skje ved visning med mindre kontrakten krever annet.

Kalori- og makromål er veiledende produktberegninger, ikke diagnose eller behandling. Vurder urealistiske input, trygge grenser, spiseforstyrrelsessensitivt språk og Safe Mode. Ikke bruk skam, absolutte helseløfter eller manipulerende målbudskap.

Minimer innsamling og logging av person-, helse- og vektdata. Sjekk formål, samtykke, lokal/ekstern lagring, sletting, eksport og tredjepartsdeling. Endringer i faktisk databruk må gjenspeiles i brukergrensesnitt og juridisk tekst før release.
