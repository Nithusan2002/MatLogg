# Beslutningslogg

Bruk denne filen for varige valg som påvirker produktretning, arkitektur, datakontrakter eller drift. Hold hvert innslag kort: dato, beslutning, begrunnelse og konsekvens.

## 2026-09-15 – Prosjektstruktur og agentarbeidsflyt

**Beslutning:** Behold ett Xcode-prosjekt og eksisterende appstruktur, samle spesifikasjoner i `docs/specs/`, og bruk `AGENTS.md` med domeneavgrensede skills i `.agents/skills/`.

**Begrunnelse:** Prosjektet er foreløpig lite nok til at en større fysisk kodeomlegging eller moduldeling ville gitt mer flyttekostnad enn verdi. Dokument- og agentstrukturen gjør ansvar og sannhetskilder tydelige uten å risikere byggeoppsettet.

**Konsekvens:** Nye filer følger eksisterende feature-/laginndeling. Separate Swift Packages eller større arkitekturomlegging vurderes først når kompileringstid, testbarhet, gjenbruk eller eierskap gir et konkret behov.
