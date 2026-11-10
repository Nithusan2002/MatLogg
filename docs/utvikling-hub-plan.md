# Implementeringsplan: Utvikling som personlig hub

Opprinnelig hub-plan. Utvidet med valgfri skrittlesing og deretter korrigert mot valgt prototype med kompakte kort og Dag/Uke/Måned etter brukerens tilbakemelding 6. november; se `decisions.md` og `design-and-user-flow.md`.

Status: første versjon er implementert og målrettet verifisert på `codex/utvikling-hub`, 6. november 2026. Resultater og verifiseringshull står i `testing.md`.

## Mål og avgrensning

Gjør Utvikling til en kortbasert oversikt der brukeren velger hva som vises og i hvilken rekkefølge. Behold navnet og MatLoggs eksisterende designuttrykk. Bruk prototypen med kortbasert oversikt som visuell retning; bildene er konseptskisser, ikke en spesifikasjon for tall, grafer eller eksakte mål.

Første versjon inneholder to områder:

- **Mat og næring:** eksisterende oversikt for siste sju dager, med registrert energi og tilgjengelige makroverdier. Behold eksisterende beregningsregler og forskjellen mellom dagsverdier, ukesverdier og mål.
- **Vekt:** siste registrering, eksisterende registreringsflyt og inngang til full vekthistorikk. Behold kilde, kg-enhet og nøytral presentasjon.

«Tilpass» gir valg av synlighet og rekkefølge. Valgene huskes lokalt. Første versjon innfører ikke Apple Helse, trening, skritt, søvn, nye dag-/måned-/årsvisninger, nye helseberegninger, backendendringer eller skyfunksjoner. Ikke vis utilgjengelige områder som tomme kort eller fungerende integrasjoner. Ingen automatisk justering av kalorimål etter aktivitet.

## 1. Isoler arbeidet

- Sjekk arbeidsstatus på nytt før oppstart. Ved planlegging var `main` endret lokalt, med endringer i prosjektfil og slettede mediefiler.
- Opprett en separat worktree med branch `codex/utvikling-hub` fra kontrollert `main`-commit. La eksisterende arbeidsendringer ligge urørt. Bruk appens worktree-verktøy.
- Les gjeldende prosjektinstruksjoner i den nye arbeidskopien. Kontroller bare nødvendige avhengigheter; manglende ressurser i eksisterende arbeidskopi skal ikke trekkes inn i hub-endringen.

## 2. Fastsett skjermadferd

- Topp: «Utvikling», kort undertekst og handlingen «Tilpass».
- Standardrekkefølge: Mat og næring, deretter Vekt. Mat vises som standard. Vekt vises som standard når profilen allerede har vekthistorikk; ellers kan det velges i Tilpass. Dette er planens foreslåtte standardadferd.
- Et eksplisitt valgt kort uten data viser en kort, relevant tomtilstand. Vekt er valgfritt og kan alltid skjules.
- Matkortet viser tydelig «Siste 7 dager» og skiller dagens verdier fra ukesoversikten. Makroer vises også uten at brukeren har satt mål; målprogresjon vises bare når mål finnes. Manglende næringsdata skal ikke bli antatte nullverdier.
- Gjenbruk dagens ukediagram og vekthistorikk. Ikke legg til ny vektsparkline eller egen detaljskjerm for mat i denne leveransen. Behold eksisterende vektregistrering og «Se alle registreringer».
- Tilpass åpnes som et ark med brytere og en tilgjengelig flyttehandling for de to områdene. Endringer gjøres i et utkast; «Lagre» bekrefter, «Avbryt» forkaster. En enkel «Gjenopprett standard» endrer utkastet.
- Begge kort kan skjules. Vis da «Velg hva du vil se her» med «Tilpass oversikten»; ikke skjul inngangen til Tilpass.
- Innlastings- og feiltilstand håndteres per område. En lesefeil i matoversikten skal ikke skjule vekt. Behold sist viste innhold ved oppdateringsfeil, men tøm forrige profils data ved profilbytte.
- Behold eksisterende personvernvalg, lokal bruk og offline-adferd. Dra ned oppdaterer lokale data.

## 3. Modell og lokal lagring av kortvalg

- Gi områdene stabile ID-er, eksempelvis `nutrition` og `weight`; ikke bruk oversatt tekst eller listeindeks som identitet.
- Lag en liten modell med rekkefølge og synlighet og et injiserbart repository for disse visningspreferansene. Bruk en lokal UserDefaults-basert implementasjon uten helseverdier i innholdet.
- Knytt valgene til eksisterende profileier. Følg prosjektets etablerte overgang mellom lokal profil og konto; huben skal ikke innføre ny identitets- eller kontokoblingslogikk.
- Manglende innstillinger gir standardoppsett. Ukjente eller dupliserte ID-er normaliseres, og ugyldig lagret format gir en kontrollert standard. Et gyldig valg om å skjule alle kort skal bevares.
- Håndter preferansene i eksisterende slettings-/tilbakestillingsflyt der profilbundne innstillinger ryddes. Kontroller eksisterende eksportkonvensjon for slike preferanser og følg den.
- Dette er lokale visningsvalg, ikke nye domenedata. Ingen SQLite-migrasjon, synkhendelse eller endring i synkkontrakten er planlagt. Dersom implementeringen viser at dette likevel trengs, vurder scope og relevante fagkrav på nytt før endringen.

## 4. Bygg skjermen med eksisterende datalag

- Del `ProgressTabView` i små featurekomponenter for matkort, vektkort og tilpasningsark. Bruk eksisterende `CardContainer`, farger og typografi.
- La en liten feature-ViewModel eie kortvalg, redigeringsutkast og lagring. Gjenbruk `ProgressViewModel`, `ProgressGoalViewModel` og `HealthProfileViewModel` for eksisterende fagdata; utvid bare der avtalt adferd krever det.
- Sett sammen nye avhengigheter i `MatLoggApp`. Views skal ikke lese UserDefaults, database eller nettverk. Ikke legg hub-logikk i `AppState`.
- Undersøk eksisterende matpresentasjon før flytting: makroverdier uten mål skal ha en tydelig vei gjennom presentasjonslaget uten å innføre nye beregningsregler.
- Kort skal ikke gjøre egne databaseoppslag under rendering. Behold beskyttelse mot utdaterte asynkrone svar ved oppdatering og profilbytte.
- Bruk `matLoggTabBarScrollClearance()` på huben og relevante push-skjermer. Tilpasningsarket følger arkets egne safe areas.

## 5. Målrettet verifisering

Bruk eksisterende testoppsett i `docs/testing.md` og en tilgjengelig, dedikert QA-simulator med syntetiske data.

- Test standardoppsett, skjul/vis, rekkefølge, lagre/avbryt, gjenoppretting og bevaring etter ny opprettelse av ViewModel/repository.
- Test normalisering av ødelagte innstillinger, gyldig tomt oppsett og isolasjon mellom profiler. Kontroller profilovergang og sletting der preferansene kobles til disse flytene.
- Kjør relevante eksisterende tester for progresjonsberegninger og vekt. Suppler bare for adferd som endres, særlig makrovisning uten mål og at gamle resultater ikke vises etter profilbytte.
- Verifiser brukerflyten «Tilpass → skjul/flytt → lagre → åpne appen igjen» med én målrettet UI-test hvis eksisterende testoppsett gjør dette praktisk.
- Inspiser skjermen i simulator med tom profil, bare mat, bare vekt og begge kort skjult. Kontroller offline-bruk, feiltilstand der den kan fremprovoseres, lys/mørk modus, stor tekst, VoiceOver og bunnmeny-klaring.
- Kjør bare berørte testsuiter først. En målrettet iOS-testkjøring gir også kompilering av berørt appkode; full testpakke og backendtester er ikke standard for denne avgrensningen.
- Gjennomgå diffen mot arkitekturprinsippene og kjør `git diff --check`. Rapporter faktisk resultat og eventuelle hull.

## 6. Dokumenter og lever for gjennomgang

- Oppdater relevante deler av `product-brief.md`, `design-and-user-flow.md`, `design-system.md`, `current-state.md` og MVP-spesifikasjonen slik at huben og tilpasningen beskrives konsekvent.
- Før den varige produktbeslutningen i `decisions.md`. Behold helseintegrasjoner som senere scope.
- Lever branch med kort endringsbeskrivelse, faktiske testresultater og skjermbilder av normal og tom tilstand. Ingen merge eller produksjonsutrulling inngår i planen.

## Ferdig når

- Mat og vekt fungerer med eksisterende data uten tap eller endret ernæringsberegning.
- Synlighet og rekkefølge kan endres og bevares etter omstart, uten å påvirke andre profiler.
- Registrering og sletting av vekt fungerer fortsatt gjennom eksisterende lagrings- og transaksjonsgrenser.
- Tomtilstander og feil gir forståelige neste handlinger; skjulte og manglende data behandles forskjellig.
- Skjermen fungerer uten nett, med stor tekst og med innhold over bunnmenyen.
- Berørte kontroller består, dokumentasjon stemmer med leveransen og ingen arkitekturavvik er innført.

## Senere leveranse: Apple Helse

Planlegges separat etter at kortoppsettet er prøvd. Avklar lesetilgang per datatype, kildeprioritet og duplikater for vekt, oppdatering/sletting, lokal lagring, eksport og tilbaketrekking av tilgang. Vurder trening og skritt først. Personvernflyt, plattformkrav og faktisk databruk må avklares før implementering. Første hub-versjon trenger ikke et generelt integrasjonsrammeverk.
