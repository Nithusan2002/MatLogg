# Grundig kontroll av MatLoggs kritiske flyter

Dato: 6. oktober 2026. Status: samlet fysisk UI-kontroll bestod 7. oktober
på siste kandidat; manuelle/brukerbaserte kontroller gjenstår.
Se [resultatene](production-readiness.md) før videre kjøring.

Målet er å dokumentere om kandidatbygget oppfyller akseptkravene i
[produksjonsberedskap](production-readiness.md). Bruk `qa-release` og
`nutrition-privacy`; ved rettelser brukes også relevante fag-skills.
Kontrollen gir ikke i seg selv tillatelse til produksjonsutrulling.

## 1. Lås testgrunnlaget og beskytt eksisterende data

- Registrer commit, lokale endringer, byggnummer, konfigurasjon, Xcode,
  enhet og iOS-versjon. Testresultater må kunne knyttes til dette grunnlaget.
- Bruk separat QA-app med egen bundle-ID og syntetiske profiler/matlogger.
  Kontroller også at database, preferanser og Keychain er isolert.
  Ikke avinstaller eller nullstill brukerens vanlige app.
- Lag et fast datasett med kjente næringsverdier: gram, ml, brøkporsjoner,
  manglende næringsdata, egne produkter og flere lokale profileiere.
- Bevar xcresult, testlogg og korte reproduksjonssteg i en varig lokal
  resultatmappe utenfor Git, ikke bare `/tmp`. Ingen ekte helse- eller
  kontodata i rapporter, skjermbilder eller logger.
- Gjennomgå åpne feil, tidligere QA-hull og endringer siden 3. oktober.
  Klassifiser hver feil etter faktisk konsekvens, særlig datatap og
  beregningsfeil. Manglende feiloversikt er et uavklart krav.

## 2. Målrettet kodekontroll og automatiske tester

Kontroller arkitekturprinsippene ved lagring, logging, gjenbruk, eksport og
kontobytte: View → ViewModel → Repository, injiserbare IO-grenser, korrekt
eierfiltrering og atomisk domeneskriving med synkhendelse. Kontroller at
releasepolicy fortsatt er `localOnly`, også ved kontokobling og nett tilbake.

Kjør først berørte suites: `BusinessRuleTests`, `PortionLoggingTests`,
`MealBatchStorageTests`, `ProfileTests`, `AuthServiceTests`, `SyncRetryTests`,
`DailyGoalsTests`, `WaterLoggingTests` og relevante gjenbruks-/måltidstester.
Utvid bare ved manglende dekning, feil eller relevante endringer.
Se [testveiledningen](testing.md) for xcodebuild-oppsett.

Verifiser eksplisitt:

- Mislykket domeneskriving eller køskriving ruller tilbake hele handlingen.
  Input beholdes, og retry gir én registrering.
- Eldre database oppgraderes uten tap; nyere/uleselig database gir kontrollert
  feil fremfor et tilsynelatende tomt nytt lager.
- Historiske næringsverdier og porsjoner består ved produktoppdatering,
  redigering, kopiering, gjenbruk, eksport og omstart.
- Konto A kan ikke lese eller eksportere konto Bs data; lokal kontokobling
  følger bekreftet valg og feil etterlater korrekt eier og data.
- Ugyldig input, avbrutte forespørsler og gamle søkesvar gir trygg tilstand.

Manglende tester for risikorelevante scenarioer suppleres før kontrollen
regnes som ferdig. Tester skal kontrollere observerbar adferd.

## 3. Fysisk gjennomgang på aktuelt kandidatbygg

Kjør på fysisk iPhone med separat QA-app. Test både vanlig skriftstørrelse
og AccessibilityXXXL; gjennomgå hovedflytene med VoiceOver.

| Flyt | Kontroll og forventet resultat |
| --- | --- |
| Førstegangsbruk uten konto | Fra oppstart til første lagrede matlogg, Angre og gjenåpning. Konto og mål er valgfrie; ingen blindvei eller skjulte handlinger. |
| Søk og skanning | Lokal råvare, kjent strekkode, ukjent vare, ufullstendige data, avvist kameratillatelse og nettfeil. Brukeren får riktig kilde/enhet og forståelig neste steg. Test ekte kamera og pakker. |
| Manuell registrering | Opprett produkt med gram/ml, velg porsjon, logg og gjenåpne. Desimalkomma og ugyldige verdier håndteres; avbryt lagrer ikke uferdig data. |
| Logging og redigering | Endre mengde/måltid på dagens og tidligere dato; slett, Angre, kopier og bruk lagret måltid. Riktig dato, antall og summer før og etter omstart. |
| Mål, vann og vekt | Lagre/rediger, avbryt, ugyldig input og omstart. Verdier og visning samsvarer; mål omtales som veiledende. |
| Offline og avbrudd | Ekte flymodus, bakgrunn/foreground, skjermlås og tvungen avslutning etter bekreftet lagring. Data består og logging fungerer uten nett. Avbrudd under skriving testes deterministisk i isolerte lagringstester i tillegg. |
| Konto | Kontokobling, avbrutt/feilet innlogging, utlogging og ny innlogging med syntetiske testkontoer. Ingen feil eier, skjult datatap eller løfte om skyrestore. Bruk staging. |
| Eksport | Del og avbryt deling, feil ved eksport og kontobytte. Filen inneholder bare riktig eiers data, matcher datasettet og gir ikke import-/restore-løfte. |

Kjør den faste strekkodekontrollen på 30–50 norske butikkvarer etter
[kontrollmalen](barcode-coverage.csv). Skill dekning, tekniske feil og
avvik mot etikett. Ikke anta at ukjent vare i seg selv er en programfeil.

## 4. Uavhengig kontroll av næringsberegning

Beregn forventede verdier uten appens beregningskode: næring per 100 g/ml
× valgt mengde / 100. Eksempel: 240 kcal og 8 g protein per 100 g skal ved
37,5 g gi 90 kcal og 3 g protein; to slike porsjoner gir 180 kcal og 6 g.

Sammenlign produktvisning, porsjonsforhåndsvisning, lagret logg,
måltids-/dagssum og eksport. Gjenta etter redigering, gjenbruk og omstart.
Kontroller gram og ml separat, brøkporsjoner, desimalkomma, null, negative
verdier, ekstreme verdier og manglende næringsstoffer. Ingen implisitt
gram/ml-konvertering eller gjetting av manglende data aksepteres.
Avtal numerisk toleranse ut fra lagringens presisjon; visningsavrunding
kontrolleres separat og skal ikke skjule beregningsavvik.

## 5. Brukerforståelse og årsaker til frafall

Start med en liten intern observasjonsrunde, foreslått 5–8 deltakere, før
godkjent ekstern pilot. Dette er kvalitativ feilfinning, ikke et statistisk
bevis for retention. Bruk syntetiske data og observer uten å forklare UI-et.

Gi oppgaver: logg første måltid, finn/skann en vare, håndter ukjent vare,
endre porsjon, rett en feil og finn eksport. Registrer fullføring, behov for
hjelp, stoppunkt, omtrentlig tidsbruk og deltakerens forklaring, uten
identifiserende eller helserelaterte opplysninger.

Be deltakerne forklare med egne ord hvor matdata lagres, hva konto gir,
hva som skjer ved tap av telefon/avinstallering, og om eksport kan brukes
til å gjenopprette appen. Enhver misforståelse utløser undersøkelse av
tekst/plassering og ny test; synlig tekst alene lukker ikke kravet.

Ranger observerte hindringer etter hyppighet og konsekvens. Skill
førstegangsfriksjon fra faktisk frafall over tid. I godkjent pilot følges
bruk etter første logging opp med frivillig, ikke-sensitiv feedback om
hvorfor deltakere sluttet. Ingen nytt analyse-SDK er nødvendig i denne planen.

Rett de vanligste dokumenterte årsakene, og gjenta de berørte oppgavene
med tidligere deltakere og nye deltakere. Dokumenter resultatet; en
utbedringsplan eller endret tekst teller ikke som bestått retest.

## 6. Feilretting, retest og beslutning

For hvert funn før: ID, kandidatbygg, scenario, forventet/faktisk resultat,
konsekvens, ansvarlig, rettelse og retest. Kritiske datataps-/beregningsfunn
stopper godkjenning umiddelbart. Bevar syntetisk reproduksjonsgrunnlag.

Etter rettelser kjøres relevant regresjon og berørt fysisk flyt på nytt.
Før endelig vurdering kjøres de kritiske flytene samlet på samme endelige
kandidatbygg. Kryss ikke av basert på tester av eldre kode.

**Go krever:** alle kritiske fysiske flyter bestått med lagrede bevis;
ingen åpne datataps-/beregningsfeil etter triage; vanlige dokumenterte
frafallsårsaker rettet og retestet; forståelseskontroll bestått.
Manglende bevis eller uavklarte funn betyr no-go for den aktuelle porten.
Øvrige konto-, personvern-, drift- og TestFlight-krav gjelder fortsatt.

Før resultater og gjenværende hull i `production-readiness.md`. Oppgi
kommandoer, miljø, pass/fail, ikke-testede forhold og eksplisitt go/no-go.
Ved blocker beholdes kandidaten i intern QA og bredere utrulling stanses;
eksport skal ikke brukes som antatt rollback eller gjenopprettingsløsning.
