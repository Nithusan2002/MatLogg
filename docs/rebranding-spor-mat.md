# Plan: MatLogg → Spor Mat

Dato: 11. november 2026. Status: lokale endringer implementert og byggkontrollert; publisering og TestFlight-distribusjon gjenstår.

## 1. Mål og scope

Brukeren skal møte navnet **Spor Mat** på iPhone, i appen, i delte måltidskort og på de offentlige informasjonssidene. Eksisterende installasjoner skal kunne oppdateres med historikk, lokale profiler, innstillinger og innlogging intakt.

Navnestrukturen er «Spor + kategori», med Spor Mat og Spor Økonomi som søsterapper. Rebrandingen endrer presentasjon, ikke funksjoner, databruk eller teknisk identitet.

Første leveranse beholder dagens ikon, farger, typografi og brukerflyt. En felles visuell profil for Spor-appene vurderes separat etter navnebyttet. Det er ikke nødvendig å redesigne ikonet for å fullføre denne planen.

### Overgang for portefølje og jobbsøknader

MatLogg er brukt som prosjekterfaring i allerede sendte søknader. Derfor skal hjemmesiden forklare sammenhengen før navnebyttet gjennomføres fullt ut i appen:

- Prosjektkort, nye CV-er og søknader bruker **Spor Mat (tidligere MatLogg)** gjennom den pågående jobbsøkingsperioden.
- Landingssiden får en synlig forklaring nær toppen, før demoen: **MatLogg heter nå Spor Mat**. Den skal kunne leses uten å åpne FAQ.
- Appen bruker **Spor Mat** som visningsnavn, med «Tidligere kjent som MatLogg» under Om.
- Gamle lenker, repo og ikon beholdes. Tidligere søknader og historiske opplysninger skal ikke omskrives eller sendes på nytt.
- Vurder å tone ned overgangsteksten etter 6–12 måneder, når jobbsøkingsbehovet er vurdert på nytt. Dette er et vurderingspunkt, ikke en automatisk fjerningsdato.

Overgangstekstene og appens synlige navn er nå implementert lokalt. Nettsidene er ikke publisert, og ny TestFlight-build er ikke lastet opp.

### Utgangspunkt og usikkerhet

- «Spor Mat» ble lagret på eksisterende appoppføring i App Store Connect for English (U.K.) i denne chatten. Senere skjermbilde viser navnet i TestFlight.
- Appens Apple-ID er fortsatt 6758135739. Release bruker `com.nithusan.MatLogg`; Debug bruker `com.nithusan.MatLogg.dev`.
- Ingen generell varemerkeavklaring er gjennomført. At Apple godtar navnet, avklarer ikke andre navnerettigheter. Før bred offentlig lansering må relevante identiske og lignende navn undersøkes i offisielle registre. Domenevalg er heller ikke besluttet.
- Arbeidskopien har eksisterende endringer i `MatLogg.xcodeproj/project.pbxproj`: buildnummer og krypteringsdeklarasjon. Disse skal bevares og skilles fra rebrandingen i gjennomgangen.
- Lokal arbeidskopi viser build 2026191005, mens brukerens TestFlight-bilde viser 2026191006. Neste buildnummer fastsettes etter kontroll av siste opplastede build og valgt kildekode.

## 2. Grenser som beskytter eksisterende brukere

Følgende beholdes i første leveranse:

| Område | Beholdes | Begrunnelse |
| --- | --- | --- |
| App-identitet | Apple-ID, Release- og Debug-bundle-ID, utviklerteam og signering | Oppdatering av samme app; Debug forblir separat |
| Innlogging | Keychain-service `app.matlogg.auth`, konto-/token-nøkler og callback-skjema `matlogg` | Unngå å miste session eller bryte retur fra innlogging |
| Lagring | Databasesti, tabeller, profil-ID-er, UserDefaults-nøkler og bilde-/cachemapper | Ingen datamigrering ved navnebytte |
| Kontrakter | Eksportformat, synkhendelser, schema-versjoner og API-endepunkter | Bevare kompatibilitet |
| Drift | Supabase-prosjekt, tillatte redirect-URL-er, Apple capabilities og entitlements | Ingen endring i tilgang eller infrastruktur |
| Intern kode | Prosjekt-, target-, scheme-, modul-, type- og assetnavn | Et internt navn trenger ikke følge visningsnavnet |

Ingen global søk-og-erstatt. «Matlogg», «matloggen» og «matlogger» kan være vanlige norske ord og skal vurderes i sammenheng.

Ingen databaseendring, datakopiering eller nullstilling er nødvendig i planlagt scope. Produksjonssynk og `DomainUploadPolicy.localOnly` beholder eksisterende innstilling. Hvis implementeringen viser behov for å endre disse grensene, stopp og avklar utvidet scope først.

## 3. Forberedelse

1. Les gjeldende Git-status og diff på nytt ved implementering. Bevar brukerens lokale endringer; ikke reset eller overskriv prosjektfilen.
2. Bruk egnet eksisterende checkout og en avgrenset arbeidsgren ved behov.
3. Bekreft nyeste opplastede TestFlight-build og kildekoden den bygger på før en ny kandidat opprettes.
4. Lag en kort arbeidsliste over forekomster: synlig merkenavn, vanlige ord, teknisk identitet og historisk dokumentasjon. Dette kan gjøres i arbeidsnotater uten ekstra dokument.
5. Kontroller hvilke språk som faktisk er opprettet i App Store Connect og hvilke konfigurasjoner som genererer appens Info.plist.

Ferdig når endringens omfang er tydelig, lokale endringer er forstått, og riktig utgangspunkt for neste build er valgt.

## 4. Navnet på iPhone og systemtekster

Berørte filer: `MatLogg.xcodeproj/project.pbxproj`, `Config/Debug-Info.plist` og `Config/Release-Info.plist`.

- Sett eksplisitt `CFBundleDisplayName` til «Spor Mat» i Debug og Release, med én autoritativ definisjon per konfigurasjon. Behold `PRODUCT_NAME` og bundle-ID-er.
- Oppdater merkenavnet i beskrivelsene for Apple Helse og lagring av måltidskort i Bilder. Kontroller både prosjektfilens genererte verdier og eksplisitte plist-verdier for overstyringer.
- Kameraets nåværende systemtekst har ikke gammelt merkenavn; vurder bare om øvrige tekster fortsatt samsvarer med faktisk funksjon. Ingen utvidelse av tillatelser.
- Behold URL-skjema og øvrige tekniske URL-identifikatorer.
- Kontroller den ferdigbygde Release-appens Info.plist; kildefilene alene viser ikke nødvendigvis det endelige resultatet.

Ferdig når iOS viser «Spor Mat» under ikonet og i relevante systemflater, Release fortsatt har `com.nithusan.MatLogg`, og ingen nye tillatelser er lagt til.

## 5. Synlige tekster i appen

Kartlagte steder som skal gjennomgås:

| Flate | Filer/område | Endring |
| --- | --- | --- |
| Oppstart | `MatLogg/App/DemoAppRoot.swift` | Appnavn og «Åpner Spor Mat» for VoiceOver |
| Velkomst og onboarding | `WelcomeView.swift`, `OnboardingView.swift`, `MatLoggOnboardingFlowView.swift` under `Views/Auth/` | Overskrifter og introduksjon |
| Konto | `Views/Auth/LoginView.swift`, `Services/AuthRepository.swift` | Registreringslenke og synlig feilmelding |
| Profil og hjelp | `Views/Profile/ProfileView.swift`, `HelpSupportView.swift` | Standard profilnavn, hjelpetekster, om-seksjon og e-postemne |
| Apple Helse | `Views/Profile/AppleHealthSettingsView.swift` | Navn i forklaringer og henvisninger til appinnstillinger |
| Utvikling | `Views/Progress/` og `App/ProgressPeriod.swift` | Kildeetiketter, vektkilder og meldinger om Helse-tilgang |
| Kamera | `Views/Home/HomeView.swift` | Forklaring før tillatelse og melding om manglende tilgang |
| Måltidsdeling | `Views/MealShare/MealShareView.swift`, `MealShareCardView.swift` | «Spor Mat-logo» og navnet på delingskortet |

Bruk «Spor Mat» konsekvent. Foretrekk «innstillingene i Spor Mat» der en genitiv blir tung. Behold eksisterende informasjon om lokal lagring, valgfri konto, datakilder og begrensninger.

Viktig spesialtilfelle: `ProgressWeightOverview.Source` har i dag raw-verdien «MatLogg». Kartlegg bruk av `rawValue` før endring. Hvis verdien brukes som teknisk identifikator, behold den og skill ut visningsteksten; ikke endre identitet for å endre etiketten. Ikke innfør en generell merkevarearkitektur eller nye ViewModels for rene tekstendringer.

Ferdig når alle aktive brukerflater viser nytt merkenavn, vanlige ord som «matloggen» fortsatt leses naturlig, og kildeinformasjon har samme betydning som før.

## 6. Bilder, deling og eksport

- Kontroller dagens ikon og logoassets for innbakt tekst. Assetnavn som `MatLoggLogo` og `MatLoggStartupLogo` kan beholdes internt.
- Behold dagens ikon i første kandidat dersom det ikke inneholder gammelt navn.
- Kontroller delingskortet visuelt med «Spor Mat», inkludert kompakt variant, lange måltidsnavn og skjult logo.
- Behold JSON-eksportens format og filnavnprefikset `matlogg-export-` i første leveranse. Prefikset inngår også i oppryddingen av eksportfiler og eksisterende tester; en kosmetisk endring er ikke nødvendig nå.
- Oppdater synlig eksportveiledning og apphenvisninger, uten å love import eller skybackup.

`APIService.swift` bruker også MatLogg i en utgående User-Agent. Vurder separat om denne identifikasjonen bør få nytt visningsnavn. Endre aldri API-adressen som del av tekstbyttet. Hvis User-Agent endres, kontroller tilhørende test og leverandørkrav.

## 7. Nettside, personvern og dokumentasjon

### Offentlige sider

Den nåværende personvernlenken i `MatLogg/App/PrivacyConstants.swift` peker til `https://nithusan.no/MatLogg/personvern.html`. Landingssidens kildekode er funnet i `matlogg-web/`: hovedinnhold i `src/App.tsx`, metadata i `index.html` og personvern i `src/PrivacyPage.tsx` / `personvern.html`. Ifølge `matlogg-web/README.md` publiserer `.github/workflows/landing-pages.yml` ved endringer på `main`. Publiseringsløpet må kontrolleres før bruk. Hovedporteføljen ligger i `/Users/nithu/nithusan2002.github.io/`, med prosjektkort i `index.html` og prosjektdialog i `script.js`.

1. Finn riktig nettstedrepo og gjeldende publiseringsløp før endring.
2. Oppdater produktnavn, sidetittel, metadata, FAQ, alternativ tekst og skjermbilder som faktisk viser gammelt navn.
3. Behold eksisterende `/MatLogg/`-adresser i første omgang. Da virker lenker fra allerede installerte versjoner fortsatt.
4. Hvis ny adresse senere velges, må gammel adresse fungere videre med passende videresending og testes før appens lenker endres.
5. Ikke kjøp domene eller flytt nettsted som del av første navnebytte.

### Klargjorte tekster til hjemmesiden

Tekstene nedenfor ligger til grunn for de lokale endringene. De innebærer ingen påstand om at appen er offentlig lansert.

**Prosjektkort på nithusan.no**

Tittel: **Spor Mat (tidligere MatLogg)**

Tillegg til eksisterende prosjektbeskrivelse:

> Prosjektet het tidligere MatLogg og videreføres som Spor Mat. Det er den samme iOS-appen som er omtalt i tidligere søknader og prosjektbeskrivelser.

Behold eksisterende, korrekte beskrivelser av teknologi og eget arbeid. Ikke skriv om øvrig porteføljeinnhold eller oppgrader test-/lanseringsstatus på grunnlag av navnebyttet.

**Landingsside på /MatLogg/**

Logo/navnetrekk: **Spor Mat**

Synlig merknad nær toppen:

> **MatLogg heter nå Spor Mat**
>
> Dette er den samme matloggingsappen som tidligere het MatLogg. Prosjektet videreføres under nytt navn og blir en del av Spor-familien sammen med Spor Økonomi.

Behold dagens hovedbudskap «Matlogging som passer hverdagen din.» og primærhandlingens plassering. Endre knappeteksten til **Se Spor Mat i bruk**. Merknaden skal være vanlig, tilgjengelig tekst som bryter naturlig på mobil, ikke en modal eller et banner som må lukkes. Bruk eksisterende typografi og fargetokens.

**Sidetittel og beskrivelse**

- Tittel: **Spor Mat (tidligere MatLogg) – matlogging på norsk**
- Beskrivelse: **Spor Mat, tidligere MatLogg, er en norsk iPhone-app for enkel matlogging og oversikt. Samme prosjekt, nytt navn. Appen er under utvikling.**

Behold eksisterende `noindex, nofollow` i denne etappen. Metadata gjør navnet tydelig i nettleseren og ved eventuell senere indeksering, men gir ingen garanti om treff i søkemotorer.

**Nytt FAQ-spørsmål**

> **Er Spor Mat det samme som MatLogg?**
>
> Ja. MatLogg videreføres som Spor Mat. Hvis du har sett MatLogg i en søknad, CV eller prosjektbeskrivelse, er dette det samme prosjektet.

Eksisterende FAQ-tekst og øvrige apphenvisninger får nytt navn når siden implementeres. Opplysninger om tilgjengelighet og beta må kontrolleres separat ved publisering.

**Appens Om-side og nye søknader**

- Om-side: **Tidligere kjent som MatLogg.**
- Prosjektoverskrift i CV/søknad: **Spor Mat (tidligere MatLogg)**.
- Ved behov i et intervju: **Jeg har videreutviklet MatLogg under navnet Spor Mat. Det er det samme prosjektet som står i søknaden min.**

### Akseptansekriterier for overgangen

- En besøkende fra en gammel søknadslenke skjønner koblingen før demoen, både på mobil og desktop.
- Prosjektkort, landingsside og sidetittel bruker begge navnene; øvrig produkttekst bruker Spor Mat.
- `/MatLogg/` og `/MatLogg/personvern.html` beholdes, med samme store M.
- Eksisterende skjermbilder beskrives fortsatt som bilder av appen; eventuelt gammelt navn i dem må ikke skjules gjennom misvisende tekst. Nye demobilder tas etter apprebrandingen ved behov.
- Teknologier, eget arbeid, faktisk funksjonalitet og test-/lanseringsstatus fremstilles korrekt.
- Endringene samler ikke inn data og påvirker ikke appens arkitektur, eierskap eller local-first-adferd.

### Personvern

Gjennomgå `matlogg-legal/privacy.md`, `matlogg-legal/app-store-data-use.md` og den publiserte personvernsiden. Bytt produktnavn uten å endre behandlingsansvarlig, formål, samtykker, datatyper eller leverandører. Ingen ny innsamling eller endret personvernversjon som tvinger samtykke bare på grunn av navnebyttet.

Bruk en faktisk revisjonsdato når teksten endres. Juridisk kilde og publisert tekst skal være samordnet før offentlig release. Avdekkede materielle avvik håndteres separat, ikke gjennom stille omskriving i rebrandingen.

### Prosjektdokumentasjon

Oppdater aktive introduksjoner i README og relevante produkt-/designdokumenter. Før én kort beslutning i `docs/decisions.md`: offentlig navn er Spor Mat; teknisk identitet beholdes. Historiske beslutninger, gamle releaseopplysninger, kommandoer og filstier skal ikke omskrives mekanisk.

## 8. App Store Connect og TestFlight

- Bekreft at eksisterende appoppføring fortsatt har riktig navn og samme Apple-ID.
- Oppdater eventuelle andre opprettede lokaliseringer som fortsatt viser MatLogg. Ikke opprett flere språk bare for navnebyttet.
- Gjennomgå eksisterende beskrivelse, undertittel, støtte-/markedsføringslenker, personvernlenke og beta-informasjon. Oppdater der det finnes gammelt merkenavn; ikke utvid markedsføringspåstander.
- Bruk en enkel betatekst: «MatLogg heter nå Spor Mat. Denne oppdateringen endrer navnet. Matloggen og innstillingene dine skal være med videre.» Bekreft databevaring før teksten brukes.
- Behold eksisterende appoppføring og grupper. En ny appoppføring skal ikke opprettes.
- Velg et ledig buildnummer høyere enn siste opplastede build. Det er ikke nødvendig å endre markedsversjonen bare for navnebyttet hvis gjeldende versjonsstatus tillater oppdateringen.
- TestFlight-opplasting, ekstern distribusjon og offentlig lansering behandles som separate steg. Avklar distribusjon før den gjennomføres; denne planen er ingen produksjonsgodkjenning.

## 9. Risikobasert verifisering

### Lokalt før arkivering

1. Gjennomgå diffen mot `docs/architecture-principles.md`: ingen ny IO i views, ingen flyttet domenelogikk, ingen endrede transaksjoner, eierregler eller synkkontrakter.
2. Søk etter gjenværende merkenavn i berørte brukerflater. Vurder treff manuelt; tekniske navn skal kunne stå igjen.
3. Valider endrede plist-/prosjektfiler og kontroller ferdigbygd metadata for Release.
4. Bygg kandidaten én gang med relevant konfigurasjon. Dette er begrunnet fordi visningsnavn og systemtekster genereres av bygginnstillingene. Unngå full testpakke uten konkret grunn.
5. Kjør eksisterende målrettede tester dersom kildeetiketter, eksportopprydding eller annen logikk faktisk endres. Nye tester skal kontrollere relevant adferd, ikke bare speile tekstkonstanter.
6. Inspiser oppstart, velkomst, profil/hjelp, Helse-henvisninger og delingskort i lys/mørk modus, med stor tekst og relevante VoiceOver-etiketter. Bruk dedikert QA-miljø ved dataskrivende tester.

### Oppdatering på fysisk iPhone

Debug har annen bundle-ID og beviser ikke oppdatering av den eksisterende TestFlight-installasjonen. Oppdateringstesten må bruke samme Release-identitet via egnet distribusjon.

- Før oppdatering: noter noen eksisterende registreringer og innstillinger uten å kopiere sensitive data inn i repo eller logger. Ikke avinstaller appen. Eksport er ikke en gjenopprettingsplan, siden appen ikke støtter import.
- Oppdater eksisterende installasjon til den nye kandidaten.
- Bekreft navn under ikonet, oppstart og de endrede tekstene.
- Bekreft mat-/vannhistorikk, mål, vekt, favoritter, lagrede måltider/bilder og profilvalg der testprofilen har slike data.
- Bekreft forventet innloggingsstatus uten å logge ut bare for å teste navnebyttet. Kontroller innlogging separat på QA-profil dersom det er relevant.
- Bekreft en lokal logging uten nett, relansering og at registreringen fortsatt finnes.
- Kontroller eksisterende Helse-valg og visning uten å endre eller slette målinger.
- Lag et delingskort og kontroller eksport i QA-profil. Ikke slett brukerens data som test.

Gamle tillatelsesdialoger vises ikke nødvendigvis på nytt etter oppdatering. Nye systemtekster kontrolleres i bygget metadata og ved behov i en separat testinstallasjon, uten å nullstille hovedinstallasjonen.

## 10. Utrulling og tilbakeføring

Anbefalt rekkefølge:

1. Klargjør prosjektkort og landingsside med overgangstekstene ovenfor, og samordne personvernnavnet. Gjennomgå diff, bygg siden og kontroller mobil/desktop.
2. Publiser hjemmesidens forklaring etter eksplisitt godkjenning. Gamle søknadslenker skal fungere før appens fulle navnebytte.
3. Implementer appens synlige navn og Om-merknad, gjennomgå diff og utfør byggkontroll og målrettet QA.
4. Klargjør App Store-/betatekster. Avklar og gjennomfør opplasting til intern TestFlight; kontroller oppdatering på iPhone.
5. Samordne eventuelle nye skjermbilder og siste nettstedstekster etter appkontrollen; publisering krever godkjenning.
6. Vurder ekstern beta eller offentlig release med egen go/no-go og gjeldende releasekrav.

Ved feil før opplasting: rett eller reverser bare rebranding-endringene. Bevar eksisterende lokale endringer.

Ved feil etter distribusjon: stans videre utrulling og lag en korrigert build med samme bundle-ID og høyere buildnummer. Ikke avinstaller appen og ikke flytt database/Keychain for å løse et navneproblem. En eldre TestFlight-build er ikke en garantert trygg datarollback.

## 11. Ferdigdefinisjon

Rebrandingen er ferdig for beta når:

- [ ] «Spor Mat» vises på iPhone, i aktive appflater og på delingskort.
- [ ] App Store Connect og relevante betaopplysninger er konsistente.
- [ ] Release-identitet, lokal lagring, innlogging og avslått synk er bevart.
- [ ] Oppdatering av eksisterende installasjon er kontrollert uten avinstallering eller datatap.
- [ ] Personvern- og støttelenker virker, også fra gamle versjoner.
- [ ] Offentlige tekster er samordnet før offentlig lansering.
- [ ] Besøkende fra gamle søknader kjenner igjen MatLogg på prosjektkort og landingsside.
- [ ] Gjenværende MatLogg-navn er tekniske, historiske eller bevisst utsatt.
- [ ] Faktiske kontroller, eventuelle hull og go/no-go er rapportert.

Skills: product-review → product-design → ios-swiftui → nutrition-privacy → qa-release. Ved utvidelse til auth, lagring eller backend må relevante offline-sync-/backend-api-skills også brukes før implementering.

Planleggingsrunden har bare lest kode, dokumentasjon og Git-diff. Ingen build, tester, datamigrering eller publisering er utført.


## Gjennomført lokalt 11. november 2026

- Landingsside, FAQ, sidetittel og personvern bruker Spor Mat, med tydelig forklaring av tidligere navn. Gamle URL-er, ikon, skjermbilder og noindex er beholdt.
- Prosjektkort og prosjektdialog i hovedporteføljen bruker begge navnene på norsk og engelsk. Eksisterende lokale endringer er bevart; egen differanse er gjennomgått mot snapshot fra før arbeidet. Linjehøyden på prosjektoverskriften er justert for det lengre navnet, og cacheversjoner for CSS/JS er oppdatert.
- Appens brukerrettede tekster, delingskort, tillatelsesbeskrivelser og CFBundleDisplayName er oppdatert. Om-siden viser tidligere navn. UI-testenes tekstforventninger er samordnet.
- Teknisk identitet, raw-verdien til ProgressWeightOverview.Source, User-Agent, API-adresser, Keychain, databasestier, eksportprefiks og callback er beholdt. Ingen ny IO eller endring i MVVM, transaksjonsgrenser, eierskap eller synk. Ingen arkitekturavvik identifisert.
- Skills brukt: product-review, product-design, ios-swiftui, nutrition-privacy og qa-release.

### Utført verifisering

- `npm run build --prefix matlogg-web`: bestått, TypeScript og Vite.
- `npm run build:css` i porteføljerepoet: bestått. `node --check script.js`: bestått.
- `plutil -lint` på Debug-/Release-plist og prosjektfilen: bestått.
- `xcodebuild build -project MatLogg.xcodeproj -scheme MatLogg -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/spormat-rebrand-build CODE_SIGNING_ALLOWED=NO`: bestått etter siste apptekstendring.
- Ferdigbygd Info.plist: CFBundleDisplayName = Spor Mat, CFBundleIdentifier = com.nithusan.MatLogg, callback-skjema = matlogg. Nye Helse-/Bilder-tekster kontrollert.
- Nettleser: desktop og 390 px mobilbredde kontrollert på begge nettstedene. Norsk/engelsk prosjektkort og norsk prosjektdialog kontrollert. Ingen konsollfeil registrert under kontrollen.
- Release-appen installert og startet i QA-simulatoren MatLogg Landing Capture; onboarding viser Spor Mat uten synlig layoutfeil.
- `git diff --check`: bestått. Endringene er presentasjon/tekst; full testpakke er ikke kjørt. Oppdaterte UI-testforventninger er ikke kjørt.

### Gjenstående porter

**Go:** gjennomgang og publisering av nettstedstekstene når brukeren godkjenner det. Forhåndsvisninger ligger på http://127.0.0.1:5173/ og http://127.0.0.1:8000/#prosjekter mens lokale servere kjører.

**No-go for offentlig apprelease ennå:** fysisk iPhone-oppdatering med eksisterende data er ikke utført; siste opplastede buildnummer er ikke avstemt; TestFlight-/App Store-tekster og alle lokaliseringer er ikke kontrollert på nytt. Signert device-arkiv/opplasting, full visuell kontroll av delingskort, stor tekst, VoiceOver og mørk modus gjenstår før endelig appgodkjenning. TestFlight-distribusjon og publisering er ikke utført. Varemerkenavn er ikke endelig avklart.


## Publisert 11. november 2026 etter brukerens godkjenning

- Porteføljen på https://nithusan.no/#prosjekter: commit `2ce3884`.
- Landingssiden på https://nithusan.no/MatLogg/: commit `b8124f3`.
- Begge publiseringsjobber i GitHub Pages fullført med success. Offentlig landingsside, prosjektkort på norsk/engelsk og norsk prosjektdialog er kontrollert i nettleser. `/MatLogg/personvern.html` svarer HTTP 200 og har nytt navn.
- Bare nettstedendringer ble committet og pushet. Urelaterte lokale porteføljeendringer og alle appendringer ble bevart lokalt. Ingen ny TestFlight-build distribuert.
- Tilbakeføring av nettstedene kan gjøres ved å reversere de to navngitte commitene; dette endrer ikke appdata eller app-identitet.
