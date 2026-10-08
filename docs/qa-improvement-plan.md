# Forbedringsplan etter fysisk QA

Dato: 7. oktober 2026. Status: under gjennomføring; datatester er grønne,
de tre tidligere røde UI-flytene har bestått fysisk retest, og alle 9
valgte UI-flyter bestod samlet på siste kandidatkode.
Pilot-/releaseporten er fortsatt no-go.

Gjennomført: oppdatert isolert QA-grunnlag, 187 grønne iOS-enhetstester,
målrettet legacy-kontovedlikeholdstest og 10 grønne kontoslettingskontroller
i lokal Supabase-QA med rollback. Kvitteringen har fått lukkeknapp, og
porsjons-/søkeresultatlayout er tilpasset svært stor tekst. Manuell
redigering på tidligere dato og porsjonsøkning etter omstart har bestått
fysisk retest. Gjenlogging/Angre har også bestått etter retting av foreldet
logg-ID i hurtigmenyens state, med 7 grønne målrettede enhetstester.
Endelige resultater føres i `production-readiness.md`.

Målet er å lukke de åpne funnene fra fysisk QA og dokumentere at ett
oppdatert kandidatbygg oppfyller [releaseporten](production-readiness.md).
[Kontrollplanen](critical-flows-qa-plan.md) beskriver testscenarioene;
denne planen angir hva som skal forbedres og i hvilken rekkefølge.

Utgangspunkt: 164 ulike enhetstester har bestått, og fem av åtte valgte
UI-flyter har bestått minst én kjøring. Tre UI-flyter er fortsatt røde.
Resultatene gjelder et arkivert QA-grunnlag uten Apple-entitlement, og
dekker ikke alle senere arbeidsendringer. Ingen samlet kandidat er godkjent.

## Prioritert gjennomføring

| Prioritet | Arbeid | Ferdigkriterium |
| --- | --- | --- |
| P0 – først | Lås oppdatert kildegrunnlag, inkludert nye konto-, eksport- og slettingsendringer. Registrer commit, lokale endringer, byggkonfigurasjon og kildehash. Hold QA-app og testdata isolert. | Kjøringene kan etterprøves og knyttes til samme grunnlag; endringer under kjøring utløser vurdering av berørt retest. |
| P0 – datarisiko | Gjennomgå og test siste endringer i AuthViewModel, AuthService/AuthRepository, DatabaseService, UserDataExportService og kontoslettingsmigrasjon. Prioriter feilet/avbrutt sletting, lokal profil etter utlogging og eksportfeil. | Ingen utilsiktet sletting, feil eier eller stille ufullstendig eksport; relevante auth-, lagrings-, eksport- og databasekontrakttester består. Bekreftet sletting følger avtalt scope og brukerens valg. |
| P1 – kritisk flyt | Rett eller avklar direkte redigering fra Hjem etter manuell logging på tidligere dato. | Ett trykk på riktig matrad åpner riktig editor; endring til Lunsj bevarer dato, mengde og næringsverdier etter lagring og omstart. Fysisk retest består. |
| P1 – tilgjengelighet | Rett eller avklar porsjonsøkning med AccessibilityXXXL. | Øk/reduser-knapper har gyldig, synlig trefflate på minst 44 × 44 pt; to brød/75 g kan endres til tre/112,5 g. Forhåndsvisning, lagring og omstart stemmer. Vanlig og svært stor tekst består fysisk. |
| P1 – gjenbruk | Rett eller avklar gjenlogging og Angre med svært stor tekst. | Brukeren kan nå søk, velge varen, gjenlogge og angre siste registrering. Opprinnelig logg og tidligere registreringer bevares; handlinger kan nås over bunnmenyen. |
| P1 – runtime | Finn opphavet til «Invalid frame dimension (negative or non-finite)» under onboarding. | Ugyldig dimensjon fjernes ved kilden; førstegangsbruk består uten advarselen med vanlig og svært stor tekst. |
| P1 – fysisk dekning | Gjennomfør kamera, ekte flymodus/skjermlås, ekte innlogging/kontobytte, eksportdeling og VoiceOver. Kontroller 30–50 norske butikkvarer mot etikett. | Resultater er dokumentert; feil, ukjente varer og dekningshull skilles. Ingen fysisk flyt er godkjent bare ut fra mock-tester. |
| P1 – brukerbevis | Gjennomfør forståelses- og friksjonstester med deltakere; følg senere faktisk frafall i godkjent pilot. | Deltakerne forstår lokal lagring, ingen skybackup fra konto og ingen import av eksport. Vanlige dokumenterte hindringer er rettet og testet på nytt. Faktisk frafall skilles fra antatt friksjon. |
| Avsluttende port | Kjør relevant regresjon og alle åtte kritiske UI-flytene på samme endelige kandidat. Vurder øvrige releasekrav. | Én samlet, etterprøvbar kandidatvurdering med pass/fail, åpne hull og eksplisitt go/no-go. |

P0 betyr at risiko må avklares før godkjenning; det er ikke en påstand om
at de nye endringene allerede har en bekreftet datatapsfeil.

## Finn årsaken før retting av UI-funn

For hver rød flyt: reproduser manuelt på fysisk enhet, sammenlign med
UI-testen og behold skjermopptak/hierarki med syntetiske data. Registrer
hvilken kontroll som vises, dens faktiske trefflate, aktiv skjerm/sheet,
valgt dato/profileier og state før og etter handlingen.

- **Hjem:** undersøk radens handling, presentasjon av editor, navigasjon,
  lasting etter manuell registrering og eventuell overlay. Fjerning av
  kortets overordnede trykkhandling er allerede prøvd uten å løse feilen;
  ikke gjenta dette som antatt løsning.
- **Porsjoner:** skill endring av ViewModel-state fra synlig oppdatering.
  Kontroller knappens layout og scrollposisjon, også når editor åpnes etter
  omstart. En ugyldig trefflate skal ikke omgås ved å redusere testens tekststørrelse.
- **Gjenbruk:** kontroller både bunnmenyens klarering og søk i sheet.
  Store søkeresultater trenger ikke få plass i sin helhet på skjermen,
  men en synlig del må kunne velges. Testens scrollstrategi må støtte dette.

Rett tester når manuell betjening og skjermhierarki viser at forventningen
er feil. Rett appen når faktisk betjening eller state er feil. Behold
akseptkravene; ikke fjern assertions eller kritiske scenarioer for å få grønt.

## Rammer for implementering

Bruk eksisterende semantiske tokens, komponenter og navigasjonsmønstre.
Bevar tydelige handlinger, minimum trefflate og tilgjengelighet ved stor tekst.
Scrollbare faneskjermer skal bruke `matLoggTabBarScrollClearance()`;
sheets kontrolleres mot egen safe area.

Følg [arkitekturprinsippene](architecture-principles.md): views videresender
handlinger, ViewModels eier feature-state, repositories skjuler IO.
Bevar local-first, atomisk domeneskriving/synkhendelse og profileierskap.
Ikke utvid arbeidet med skybackup, import eller nytt analyse-SDK.

Ved rettelser brukes ios-swiftui; lagring/synk bruker offline-sync;
auth, API og SQL bruker backend-api; næring/persondata bruker nutrition-privacy.
Bruk product-design ved endret layout/UX, product-review ved større
flyt-/scopeendringer, og qa-release for avsluttende vurdering.
Produksjonsutrulling, endring av auth/tilgang og destruktive migrasjoner
krever avklaring etter prosjektets regler; denne planen godkjenner ikke slike tiltak.

## Resultater og godkjenning

Før hvert funn med ID, reproduksjon, konsekvens, ansvarlig, rettelse,
testgrunnlag og faktisk retestresultat. Ansvarlige tildeles før gjennomføring.
Arkiver xcresult og logger varig utenfor Git. Ikke ta med ekte persondata.
Oppdater eksisterende `production-readiness.md` fremfor å lage nye rapportfiler.

Etter hver rettelse kjøres minste relevante regresjon og fysisk berørt flyt.
Avslutt med samlet UI-runde på endelig kandidat; utvid automatiske tester
etter endringsrisiko. Grønt i lokal QA uten Apple-entitlement er ikke bevis
på ekte innlogging eller korrekt releasearkiv.

**No-go består** til kritiske fysiske flyter er grønne, feiltriage viser ingen
åpne datataps-/beregningsfeil, brukerforståelsen er verifisert, og vanlige
dokumenterte frafallsårsaker er rettet og retestet. Andre konto-, personvern-,
drift- og TestFlight-porter består. Intern observasjon kan samle bevis før
godkjent ekstern pilot; ingen offentlig lansering følger automatisk av grønn QA.
