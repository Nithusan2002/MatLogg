---
name: qa-release
description: Planlegg risikobasert QA og vurder release readiness for MatLogg-funksjoner, sikkerhetskritiske endringer, piloter og produksjonsutrulling.
---

# QA og release

Les berørte spesifikasjoner, diffen, eksisterende tester og `docs/specs/09-risks-mitigation.md`.

Tilpass verifisering til risiko. Prioriter tester for datatap, feil ernæringsberegning, auth/eierskap, synk/idempotens, sletting, personvernvalg og kritiske brukerflyter. Kontroller også loading, tomtilstand, offline, ugyldig input og gjenoppretting etter feil.

For release, krev at iOS og backend bygger, relevante automatiske tester består, migrasjoner og klient/server-kompatibilitet er vurdert, hemmeligheter og logging er kontrollert, og personvern-/App Store-tekst samsvarer med faktisk adferd. Skill blocker fra oppfølging.

Lever verifiseringsresultat, ikke bare sjekkliste: kommandoer/testmiljø, pass/fail, kjente hull, rollback eller avbøtende tiltak og tydelig go/no-go-anbefaling. Ikke godkjenn produksjon på antakelser.
