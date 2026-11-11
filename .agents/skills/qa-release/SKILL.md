---
name: qa-release
description: Planlegg risikobasert QA og vurder release readiness for MatLogg-funksjoner, sikkerhetskritiske endringer, piloter og produksjonsutrulling.
---

# QA og release

Les berørte spesifikasjoner, diffen, eksisterende tester og `docs/specs/09-risks-mitigation.md`.

Tilpass verifisering til risiko. Prioriter tester for datatap, feil ernæringsberegning, auth/eierskap, synk/idempotens, sletting, personvernvalg og kritiske brukerflyter. Kontroller også loading, tomtilstand, offline, ugyldig input og gjenoppretting etter feil.

For release, fastsett først hva som endres og distribueres:

- Lokal iOS-release: verifiser iOS-kandidaten og relevante automatiske tester. Kontroller at `DomainUploadPolicy.localOnly` og avslått synk bevares. Backend-build og migrasjonskjøring kreves ikke bare fordi klienten distribueres; kontotjenester og andre eksterne integrasjoner som kandidaten bruker, må fortsatt ha relevante kontroller.
- Backend-/synkrelease: verifiser berørte backendkomponenter og relevante tester, migrasjoner, RLS/eierskap og klient/server-kompatibilitet. Bygg og test klienten når endringen påvirker den. Synkaktivering er et eget scopevalg og krever alle gjeldende produkt-, personvern- og tekniske porter; en backenddeploy åpner ikke synk.

For begge: kontroller hemmeligheter og logging i berørt omfang, og at personvern-/App Store-tekst samsvarer med faktisk adferd. Bruk `docs/production-readiness.md` for øvrige releaseporter. Skill blocker fra oppfølging.

Lever verifiseringsresultat, ikke bare sjekkliste: kommandoer/testmiljø, pass/fail, kjente hull, rollback eller avbøtende tiltak og tydelig go/no-go-anbefaling. Ikke godkjenn produksjon på antakelser.
