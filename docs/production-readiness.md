# Produksjonsberedskap

## Aktiv releaseport: lokal app med valgfri konto

Lanseringsvalget 3. oktober 2026 er lokale domenedata uten opplasting.
Kravene under om domeneopplasting, hosted domene-backup/PITR og serverrestore
holdes som framtidig skyport og historiske funn. De blokkerer ikke i seg selv
en lokal lansering. Ingen betalt tjeneste eller serverkonfigurasjon er endret.

Lokal release krever grønne lagrings-/eierskaps-/eksporttester, oppgraderbar
SQLite, riktig tekst om datatap og eksport, samt fysisk QA av kritiske flyter.
Supabase Auth er fortsatt aktiv: DPA/SMTP, provideroppsett, kontosletting,
sikkerhet, driftsberedskap for konto og App Store-opplysninger må avklares.
Lokal modus løser ikke disse eksisterende personvernpunktene.

iCloud-/Finder-restore er uverifisert og tilbys ikke som produktløfte. JSON
kan ikke importeres. Full telefonrestore og produksjonsutrulling er eget scope.
**Go/no-go:** produksjonsutrulling er fortsatt no-go inntil de aktive
konto-/personvern- og releasekravene er lukket; teknisk lokal modus kan testes.

Dette dokumentet er den operative minimumsporten for MatLogg-pilot og senere
produksjon. Local-first gjør at logging kan fortsette når backend er utilgjengelig,
men det fjerner ikke risiko knyttet til konto, persondata, synk eller serverkopier.

### Obligatoriske akseptkrav før pilot og release

- Kritiske flyter skal bestå på fysisk iPhone med aktuelt kandidatbygg:
  førstegangsbruk uten konto, søk/skanning og manuell registrering,
  porsjonsvalg og næringssummer, redigering/sletting/Angre, offline logging,
  gjenåpning med bevarte data, kontokobling/utlogging og eksport.
  Dokumenter bygg, enhet/iOS-versjon, teststeg og faktisk resultat.
- Ingen åpne feil som kan gi datatap eller feil næringsberegning aksepteres,
  uansett feilens prioritet. Rettelsen og relevante regresjonstester skal
  bestå før porten kan godkjennes.
- De vanligste årsakene til frafall skal identifiseres fra pilotobservasjoner
  og brukerfeedback, prioriteres etter hyppighet og konsekvens, rettes og
  testes på nytt i de berørte flytene. Dokumenter funn, grunnlag for
  prioriteringen, rettelse og resultat av ny test. Antatte årsaker alene
  eller en planlagt rettelse lukker ikke kravet.
- Brukere skal forstå at matdata lagres lokalt, at konto ikke gir skybackup
  eller kontobasert gjenoppretting, og at eksport ikke kan importeres i
  MatLogg. Kontroller teksten ved førstegangsbruk, konto og eksport, og la
  pilotbrukere forklare begrensningene med egne ord. Eksport skal ikke
  omtales som en gjenopprettbar backup. Data kan gå tapt ved avinstallering
  eller tap av telefonen.

Manglende eller mislykket verifisering av disse kravene gir **no-go** for
godkjenning av pilot og release. Intern QA kan brukes til å samle bevis;
tidligere grønne deltester er ikke en samlet godkjenning av kandidatbygget.

### Kontroll mot akseptkravene – 2026-10-06

**Resultat: no-go; kravene er bare delvis dokumentert oppfylt.** Dette er
kode- og dokumentgjennomgang, ikke en ny fysisk testkjøring.

| Krav | Vurdering og manglende bevis |
| --- | --- |
| Kritiske flyter på fysisk enhet | Delvis. Fysisk QA 3. oktober dokumenterer 76 enhetstester og tre UI-flyter. Full dekning av skanning/kamera, manuell registrering, porsjonsvalg/næringssummer, redigering/sletting, kontokobling/utlogging og ekte offline-/låseøvelse på aktuelt kandidatbygg er ikke dokumentert. Kode er endret etter denne kjøringen (seneste commit ved kontroll: `13e85b5`, 5. oktober). |
| Ingen åpne feil som gir datatap eller feil næringsberegning | Ikke bekreftet. Lokal lagring bruker transaksjoner og logging validerer mengde/næringsverdier; porsjonstester dekker historiske verdier, redigering, gjenbruk og eksport. Dette er ikke bevis på at alle slike feil er lukket. Samlet feiltriage og relevante grønne regresjonsresultater for kandidatbygget mangler. Gjennomgangen påviser ikke en konkret ny datataps- eller beregningsfeil. |
| Vanligste frafallsårsaker rettet og testet på nytt | Ikke dokumentert. Onboarding, logging og feilmeldinger er forbedret, men det finnes ikke dokumenterte pilotobservasjoner med hyppighet, prioritert frafallsliste og nye testresultater som lukker kravet. Strekkode-baseline er også fortsatt en tom kontrollmal. |
| Lokal lagring forstått | Teksten er implementert i førstegangslogging, LoginView, Profil og hjelp: konto gir ikke skybackup, data kan gå tapt, og eksport kan ikke importeres. App-root bruker `localOnly`; releasepolicy åpner ikke domeneopplasting. Faktisk brukerforståelse er ikke dokumentert med pilottest. |

Verifisering: målrettet lesing av kode, tester og dokumentasjon samt
`xcrun devicectl list devices` (fysisk iPhone tilkoblet). Tidligere oppgitte
xcresult-filer under `/tmp/MatLoggPhysicalSyncQA/Logs/Test/` finnes ikke lokalt
ved kontrollen; resultatene over er derfor dokumenterte historiske resultater,
ikke selvstendig bekreftet fra rårapporter. Ingen build eller tester er kjørt
på nytt. Ingen kode, databruk eller arkitektur er endret.

Neste steg: kjør kritiske flyter på et identifisert kandidatbygg i separat
QA-app, arkiver resultatene, gjennomfør feiltriage og pilotens forståelses-/
frafallstester, og rett og test funn på nytt før godkjenning.
Gjennomføringen er beskrevet i [plan for grundig kontroll](critical-flows-qa-plan.md).

### Fysisk kontroll 2026-10-07 – utført delkontroll, fortsatt no-go

Videre retting og retest følger [forbedringsplanen](qa-improvement-plan.md).

Kildegrunnlag: `13e85b5a161ece2a4e9cd619cd3f4c273c7c8885` med lokale
QA-/dokumentendringer. Xcode 27.0 (27A266a), fysisk iPhone 17, iOS 27.0
(24A435). Separat QA-app `com.nithusan.MatLogg.CriticalQA.MatLogg` med
eget app-/Keychain-sandbox; syntetiske data. Originalappen ble ikke nullstilt.
Testene kjørte fra isolert kildekopi utenfor repoet. Apple-entitlement ble
fjernet bare i kopien etter provisioningfeil; ekte Apple-innlogging og
releasekonfigurasjon er derfor ikke verifisert av disse kjøringene.

Resultater og eksakte xcodebuild-kommandoer ligger i
`/Users/nithu/MatLogg-QA/2026-10-07-critical/` (xcresult, logger,
JSON-oppsummeringer og vedlegg). Første signeringsforsøk er bevart under
`/Users/nithu/MatLogg-QA/2026-10-06-critical/`. Rapporterte resultater her er
lest fra nye xcresult-filer, ikke basert på tidligere dokumenterte kjøringer.

- `Core.xcresult`: 100 tester bestod, 0 feil (118 kjøringer med parametere).
  Dekker beregningsregler, porsjoner, atomiske måltidsskrivinger/rollback,
  profil/eksport/eierskap, auth-lagring, lokal opplastingspolicy, mål, vann,
  gjenbruk og lagrede måltider.
- `Flows.xcresult`: 63 enhetstester bestod; tre av åtte UI-tester bestod.
  Grønt: mål med omstart, første logging/Angre/gjenåpning og svært stor tekst
  i førstegangsbruk. Fem UI-flyter feilet. HTTP/PostgreSQL-integrasjon inngikk
  ikke i denne lokale kontrollen.
- `Retest2.xcresult`: ni beregningstester bestod, inkludert ny håndberegnet
  fasit gjennom gram/ml, redigering, SQLite-omstart, dagssum og JSON-eksport.
  Lagringsinformasjon og vannlogging/omstart/retting bestod etter retting av
  utdaterte testforventninger. Tre UI-flyter feilet fortsatt.
- `HomeFix.xcresult`: ni beregningstester bestod; direkte redigering og
  gjenbruk feilet fortsatt. Den diagnostiske appendringen er reversert.
  Samlet er 164 ulike enhetstester dokumentert grønne i denne runden;
  fem av åtte valgte UI-flyter har bestått minst én kjøring, tre er åpne.
  Dette er ikke én samlet grønn kjøring av endelig kandidat.

Under kontrollen kom det nye arbeidsendringer i blant annet AuthViewModel,
AuthService, AuthRepository, DatabaseService, UserDataExportService,
WelcomeView og ProfileView samt tilhørende tester. Disse ble ikke kopiert inn
i det arkiverte testgrunnlaget. De er ikke overskrevet eller godkjent her.
`source-hashes.json` og `changes-during-qa.json` identifiserer forskjellene.
Ny kandidat må låses og relevante tester kjøres på de nye endringene.

Åpne funn ved denne delkontrollen:

| Funn | Bevis og videre kontroll |
| --- | --- |
| Direkte redigering fra Hjem åpner ikke forventet editor | Reprodusert etter manuell logging på tidligere dato. Diagnostisk fjerning av kortets overordnede trykkhandling løste ikke feilen på fysisk enhet (`HomeFix.xcresult`); endringen er reversert. Årsaken er uavklart; ikke lukket. |
| Porsjonsøkning ved AccessibilityXXXL | Første kjøring beholdt 2 brød/75 g etter økning; retest fikk ugyldig trefflate for økningsknappen. Beregning/lokal snapshot er grønn, men fysisk betjening med stor tekst er uavklart. |
| Gjenlogging/Angre med svært stor tekst | Første kjøring trykket en handling under bunnmenyen; retest kom videre til søk, men klarte ikke å nå det store søkeresultatet. Testens scrollstrategi og faktisk tilgjengelighet må undersøkes videre. |
| Runtime-advarsel | «Invalid frame dimension (negative or non-finite)» er fortsatt registrert under onboarding. Ikke forklart eller lukket. |

Ingen datataps- eller næringsberegningsfeil er påvist i de kjørte testene.
Dette lukker ikke kravet om ingen åpne slike feil i hele appen.
Ekte kamera/etikettbaseline, flymodus/skjermlås som funksjonstest,
ekte innlogging/kontobytte, full VoiceOver, releasearkiv og observasjoner
med deltakere er ikke utført. Brukerforståelse og vanligste frafallsårsaker
kan ikke godkjennes uten faktiske brukerobservasjoner.

Skills: qa-release, nutrition-privacy, ios-swiftui, offline-sync og
product-design. Ingen lagrings-, synkkontrakts- eller auth-endring i repoet.
Arkitekturkontroll: QA-rettelser holder IO i eksisterende lag; ingen nye
avhengigheter, ingen endring i transaksjonsgrenser/eierskap eller opplastingspolicy.
**Go for videre intern QA; no-go for pilot-/releasegodkjenning.**

## Forbedringsrunde 2026-10-07 – resultater og åpne porter

Oppdatert QA-grunnlag og resultater er bevart under
`/Users/nithu/MatLogg-QA/2026-10-07-improvement/`, med kildekopi,
hashmanifest, logger og xcresult. Fysisk iPhone 17/iOS 27.0 og Xcode 27.0.
Isolerte QA-bundle-ID-er brukes; Apple-entitlement er fjernet bare fra kopien.
Ingen produksjonsdeploy, reset av brukerappen eller auth-/tilgangsendring
er utført av denne QA-runden.

- `Core.xcresult`: **187 enhetstester bestod, 0 feil** på fysisk enhet.
  Dette omfatter de nye konto-/eksportendringene ved tidspunktet for kopiering.
- Legacy `auth-maintenance.test.ts` bestod med testkonfigurasjon.
- `account_deletion.test.sql`: **10 pgTAP-kontroller bestod** mot separat,
  lokal `supabase_db_matlogg-deletion-qa`. Migrasjon `20261007120000` var
  registrert i denne databasen. Testdata og pgTAP-oppsett ble kjørt i en
  transaksjon med rollback; ingen database-reset eller migrasjonsdeploy.
- Første samlede UI-runde på forbedret layout: fem av åtte flyter bestod.
  Manuell redigering, porsjonsøkning og gjenbruk feilet fortsatt.
  Ny retest bruker fersk profil og korrigert scroll-/ventelogikk.
- `Retest.xcresult`: de tre flytene feilet fortsatt. Manuell redigering
  beholdt en deaktivert lagreknapp; porsjonstestens rullehjelper slo opp en
  ScrollView som ikke fantes; gjenbrukstesten nådde ikke måltidsrommet.
  Synlighet og valgt tilstand kontrolleres nå før handlingene.
  Redigeringstesten antok også et startmåltid selv om appen velger dette
  etter klokkeslett. Den velger nå Frokost eksplisitt før flytting til Lunsj;
  ellers er deaktivert lagring korrekt når loggingen allerede er i Lunsj.
- `VisibleControls.xcresult`: kjøringen mistet autorisasjon til UI-testing
  etter en låst enhet. Dette er en avbrutt miljøkjøring og gir ingen ny
  konklusjon om appens flyter. Ny fysisk kjøring venter på ulåst enhet.
- `ConnectedRetest.xcresult` og `AutomationRetry.xcresult`: iPhonen var
  tilkoblet og runneren startet, men begge forsøk fikk tidsavbrudd ved
  aktivering av UI-automatisering. Ingen av de tre flytene ble kjørt;
  dette er miljøfeil og endrer ikke tidligere testresultater.
- `UnlockedRetest.xcresult`: UI-automatisering startet etter opplåsing,
  men tre tester feilet i navigasjonen. `ManualIsolated.xcresult` viste
  et uferdig QA-utkast som påvirket manuell registrering.
- `CleanInstall.xcresult`: ny QA-bundle-ID ga ren appinstallasjon.
  Manuell logging på tidligere dato nådde redigering og Lunsj-raden, men
  siste kontroll etterspurte Hjems datoknapp inne i dagsloggen. Testen er
  korrigert til å gå tilbake først. `ManualFinal.xcresult` feilet fortsatt
  ved datokontrollen; full flyt er derfor ikke godkjent.
  Porsjonstesten lagret to brød, men nådde ikke forventet porsjonsoversikt
  etter omstart. Gjenlogging nådde andre søk, men feilet kontroll av
  gjenloggingsvalget. Ingen av de tre har en grønn fullføring.
- `ExplicitState.xcresult`: **manuell logging/redigering på tidligere dato
  og porsjon 2 → omstart → 3 ved AccessibilityXXXL bestod** på fysisk iPhone.
  Porsjonstesten oppretter nå eksplisitt lokal profil og bevarer den ved
  omstart. Dette erstatter de tidligere røde resultatene for disse to flytene.
- `FreshRunner.xcresult`: gjenlogging kom til sluttkontrollen, men det var
  én rad etter Angre i stedet for to. Første kvittering kan dekke andre
  trykkmål. Ny test lukker første kvittering før andre logging og krever
  fortsatt at Angre bevarer begge tidligere registreringer.
  `RepeatReceipt.xcresult` venter på ulåst fysisk enhet; ingen konklusjon ennå.
- Endelig retest: `RepeatReceipt.xcresult` viste at andre gjenlogging åpnet
  mengdevalg. Årsaken var en foreldet logg-ID i hurtigmenyens feature-state
  etter første vellykkede lagring. `QuickLogViewModel` erstatter nå dette
  valget med produktet og loggingen returnert fra repositoryet.
- `RepeatStateFix.xcresult`: **gjenlogging to ganger og Angre bestod på
  fysisk iPhone ved AccessibilityXXXL**; originalen og første gjenlogging
  ble bevart. Sammen med `ExplicitState.xcresult` er alle de tre tidligere
  røde flytene nå fysisk retestet grønne.
- `QuickLogRegression.xcresult`: **7 målrettede enhetstester bestod**,
  inkludert ny regresjon for to påfølgende gjenlogginger med siste lagrede
  logg-ID, korrekt eier/mengde/energi og kvittering for siste registrering.
  Testartefaktene ble bygget på nytt, og ny test er eksplisitt registrert i loggen.

Endringer i denne runden: synlig lukkeknapp på loggingens kvittering,
vertikal enhetsvelger og begrenset feltbredde ved stor tekst, full radbredde
til søkeresultattekst ved tilgjengelighetsstørrelser, og vern mot negativ
bredde i onboardingens fremdriftslinje. Runtime-advarselen om ugyldig
dimensjon opptrer fortsatt og er ikke lukket.

Testdiagnose: kvitteringen kan dekke radene; debugprofilen akkumulerer data
mens Hjem viser tre rader per måltid; faste lagreknapper kan dekke testens
trykkmål; og gjenbrukstesten scrollet ned selv om loggen var øverst.
Disse funnene er grunnlag for retest, ikke bevis for at de tre flytene er løst.

Arbeidsområdet har fått nye parallelle endringer i modeller, lokal lagring,
manuell logging og konto under kjøringen. `workspace-differences.json`
identifiserer forskjellene mot QA-kopien. De er bevart og ikke godkjent her.
Grønne tester av kopien gjelder ikke automatisk disse senere endringene.

Arkitekturkontroll: endringene er visuelle, testrelaterte og oppdaterer
feature-state i eksisterende ViewModel etter vellykket repositoryskriving, uten ny IO,
domeneregel, transaksjonsgrense, profileierskap eller synkformat. Enhet og
kilde beholdes i søkeresultatet. Eksisterende komponenter/tokens brukes.
Skills: ios-swiftui, product-design, nutrition-privacy, offline-sync,
backend-api og qa-release. `git diff --check` bestod.

**No-go består.** De tre målrettede fysiske retestene er grønne; ekte kamera,
flymodus-/låseøvelse, Apple-innlogging, full VoiceOver, brukerforståelse,
frafallsobservasjoner og endelig kandidatkontroll gjenstår.

## Ny kandidatkontroll 2026-10-07

Kildekopi, hashmanifest, commit og arbeidsdiff er bevart under
`/Users/nithu/MatLogg-QA/2026-10-07-final-candidate/`. Kopien inkluderer
de nyere endringene for uferdig logging og lokal lagring. Separat QA-app,
syntetiske profiler, fysisk iPhone 17/iOS 27.0. Apple-entitlement er fortsatt
fjernet bare fra QA-kopien; ekte Apple-innlogging er ikke kontrollert her.

- `Storage.xcresult`: 104 målrettede enhetstester bestod, blant annet
  atomisk lagring, profil/eierskap og håndberegnet gram/ml-næring med eksport.
- `FreshCandidate.xcresult`: 16 utkast-/hurtigloggingstester bestod,
  inkludert alle 9 nye utkasttester. Seks av ni UI-flyter bestod i samme
  kjøring: utkast overlevde tvungen avslutning, manuell redigering på tidligere
  dato, lokal lagringsinformasjon, gjenlogging/Angre og begge vanntester.
- Tre UI-tester feilet: neste introside med stor tekst, åpning av produkt
  med tastaturet fremme og porsjonsoversikt etter omstart. Opptaket viste
  to porsjoner i editoren; testens drag gikk over mengdekontroller.
  Drag er flyttet til venstre marg og søketreffet treffes på den synlige
  venstre delen, uten å endre testenes forventede resultat.
- `TouchTargets.xcresult`: alle tre retester bestod etter korreksjon av
  trykkpunkt/rullebane. Ingen app- eller beregningsendring var nødvendig.
- `FinalUI.xcresult`: **alle 9 UI-flyter bestod i én samlet fysisk kjøring**
  med de endelige testene og samme kandidatkode. Hashkontroll etterpå viser
  samsvar med klientkoden i arbeidsområdet, med eneste registrerte avvik
  at Apple-entitlement er fjernet fra QA-kopien.
- `Offline.xcresult`: brukeren bekreftet flymodus på og Wi-Fi av, men iOS
  nektet å starte runneren fordi utviklersertifikatet ikke var betrodd.
  Ingen tester kjørte. Faktisk offlinebruk er derfor fortsatt uverifisert;
  sertifikatet må verifiseres før en ny kontroll uten nett.
  Brukerens skjermbilde bekreftet også «Kan ikke verifisere app» for selve
  QA-appen og krav om internett for godkjenning av utvikleren. Den manuelle
  offline-/låsekontrollen er derfor heller ikke gjennomført; ingen konklusjon
  om lokal lagring trekkes fra denne signeringsblokkeringen.

- `RecoveryResume.xcresult`: nytt forsøk på fysisk utkastgjenoppretting
  startet runneren, men iOS brukte for lang tid på å aktivere UI-automatisering
  (`Timed out while enabling automation mode`). Ingen test ble gjennomført.
  QA-appen kunne startes med `devicectl`; dette dokumenterer oppstart, ikke
  offlinebruk eller gjenoppretting. Tidligere grønne resultater er uendret.

- `RecoveryUnlocked.xcresult`: målrettet fysisk retest av
  `testManualInputSurvivesTerminationAndAmountReopens` bestod (1 test,
  0 feil) etter at brukeren låste opp telefonen. Utkast etter terminering,
  gjenåpning av mengdevalg og endelig lagring er bekreftet på samme QA-bygg.
  Nettet var ikke dokumentert avslått; resultatet lukker ikke offlineporten.

- `OfflineRecoveryVerified.xcresult`: brukeren bekreftet klar etter
  instruksjon om flymodus på og Wi-Fi av. Runneren ble igjen blokkert av
  utviklersertifikatet; ingen test kjørte. Selve QA-appen startet deretter
  med `devicectl` uten nett. Manuell kontroll av 50 g «Utkast QA»,
  næringsverdier og bevaring etter lukking/skjermlås ble deretter utført
  manuelt, se resultatet nedenfor.

- Manuell offlinekontroll på fysisk iPhone: «Utkast QA» ga ingen lokale
  treff, så brukeren ble instruert til å opprette «Offline QA» manuelt
  (per 100 g: 100 kcal, 10 g protein, 10 g karbohydrat, 2 g fett), logge
  50 g, lukke appen, låse telefonen i 20 sekunder og åpne igjen, fortsatt
  med flymodus på og Wi-Fi av. Brukeren bekreftet «det er bevart».
  **Bevaring etter offline logging og lukking/skjermlås er manuelt bekreftet.**
  Brukeren bekreftet deretter også visningen av 50 kcal / 5 g protein /
  5 g karbohydrat / 1 g fett. **Næringsvisning i dette offline-scenarioet
  er manuelt bestått.** Ingen automatisert offlinekjøring bestod. Dette dekker
  ikke avbrudd midt under skriving eller andre offlineflyter.

- Ekte skanning på fysisk iPhone: brukeren skannet YT Proteinyoghurt
  med bringebærsmak, 430 g, strekkode `7038010071386`, og bekreftet
  samsvar mellom næringsverdiene i appen og etiketten. Vareidentiteten
  er dokumentert med vedlagt produktbilde; bildet viser ikke selve
  appresultatet eller næringstabellen. Ført i `barcode-coverage.csv`.
  Én vare er kontrollert; baseline på 30–50 varer og øvrige kamerascenarioer
  er ikke fullført. Ingen responstid er målt.

Runtime-advarsel om ugyldig dimensjon forekommer fortsatt. Resterende
kamera-/etikettbaseline, Apple-innlogging, full
VoiceOver og forståelses-/frafallsobservasjoner gjenstår. Ingen ny
datataps- eller beregningsfeil er bekreftet, men disse portene er ikke lukket.

Kun UI-testene er endret i denne kandidatkontrollen. Ingen endret IO,
domene-/næringsregel, transaksjonsgrense, profileierskap eller synkkontrakt.
`git diff --check` bestod. Skills: ios-swiftui, nutrition-privacy og qa-release.

**No-go består.** Automatisk kandidatkontroll er grønn og manuell offline
bevaring og næringsvisning er bekreftet. Resterende kamerakontroll, Apple-innlogging,
VoiceOver og brukerobservasjoner gjenstår.

## Aktiv cutover-plan

Supabase er målplattform. Staging finnes i `eu-north-1` med migrasjoner,
Edge Functions, auth callback, Vault/Cron og avslått synk-kill-switch. Opprett
senere et separat produksjonsprosjekt i samme EØS-region, og deploy kun de
versjonerte filene i `supabase/`. Konfigurer SMTP, Apple-provider, backup/PITR
og varsling per miljø. Produksjonsmiljøet i GitHub skal kreve manuell
godkjenning.

Punktene nedenfor om NestJS/Prisma gjelder legacy-backenden mens den beholdes
under piloten. Den skal ikke reaktiveres etter produksjonscutover.

## Miljøer og utrulling

- Bruk separate PostgreSQL-databaser og hemmeligheter for staging og produksjon.
- Bygg `backend/Dockerfile` med `runtime` som kjøremål. Kjør migrasjoner som en
  separat engangsjobb fra `migration`-målet før ny backend startes.
- Bruk Node.js 24 LTS som definert i container og CI; ikke rull ut på EOL-runtime.
- Sett minst `NODE_ENV=production`, `DATABASE_URL`, et tilfeldig `JWT_SECRET` på
  minst 32 tegn og korrekt `TRUST_PROXY_HOPS` for plattformen.
- La `CORS_ALLOWED_ORIGINS` være tom når bare native-klienten bruker API-et. Hvis
  webflater legges til, oppgi eksakte kommaseparerte HTTPS-origins.
- Swagger er av i produksjon. Midlertidig aktivering krever
  `SWAGGER_ENABLED=true` og tilgangskontroll i plattformen.
- Backend rulles ut og verifiseres før en klient som avhenger av den. Synkflagget
  i iOS skal forbli av til staging-portene nedenfor er grønne.

## Hemmeligheter og data

- Oppbevar databasepassord og JWT-hemmelighet i plattformens secret manager;
  aldri i image, repo, CI-logg eller mobilklient.
- Aktiver kryptering, automatiske PostgreSQL-backuper og point-in-time recovery.
- Utfør og dokumenter en restore til en separat database før pilot.
- Logger og feilrapportering skal ikke inneholde token, e-post, vekt,
  ernæringslogger, synkpayload eller andre brukerdata.
- Verifiser eksport, soft-delete, tokenrevokering og permanent purge mot faktisk
  personvernerklæring og App Store-opplysninger.

## Overvåkning og varsler

Før pilot skal plattformen samle aggregerte, ikke-sensitive målinger for:

- tilgjengelighet, 5xx-rate og p95/p99-responstid
- PostgreSQL-tilkoblinger, lagring og mislykkede migrasjoner
- antall synkbatcher, avviste hendelser og 429-svar uten payloadinnhold
- mislykket innlogging/refresh som rate, aldri identifiserende verdier

Varsle ved vedvarende 5xx-rate over 1 %, health-feil, databaseutilgjengelighet
eller rask vekst i avviste synkhendelser. Angi én ansvarlig mottaker under pilot.

## Staging-port

1. Supabase-CI er grønn: database-reset, lint, pgTAP, Deno check/lint/test og
   målrettet iOS-bygg/test. Legacy backend-CI holdes grønn fram til opprydding.
2. Produksjonsimaget starter som ikke-root og svarer på `/health`.
3. Dev-login og Swagger er utilgjengelige med produksjonskonfigurasjon.
4. Auth, eierskap, duplikatlevering, tapt ACK, delvis avvist batch og retry er
   verifisert mot staging.
5. Rate limiting gir 429 uten at vanlig synk eller token-refresh blokkeres.
6. Offentlig trafikk har delt/plattformstyrt begrensning; den innebygde
   Throttler-telleren er bare per backendinstans.
7. Produksjonsavhengigheter har ingen uavklarte critical/high-funn. Kjente funn
   i NestJS 10 krever kontrollert rammeverksoppgradering eller dokumentert aksept.
8. Backup er opprettet og restore er demonstrert.
9. Rollback til forrige image er demonstrert uten å rulle tilbake en destruktiv
   migrasjon.
10. Personvern-/App Store-tekst samsvarer med databruk og leverandører.
    Før helsedata lastes opp, er både GDPR artikkel 6-grunnlag og artikkel 9-unntak
    avklart og dokumentert. Hvis uttrykkelig samtykke brukes, er samtykke før
    opplasting og tilbaketrekking verifisert; lokal logging fungerer fortsatt.
    Apparkivet inneholder PrivacyInfo.xcprivacy og korrekte begrunnelser for
    required reason APIs. Kontroller også avhengighetenes manifester og samlet
    privacy report. Open Food Facts sin lagring er avklart for App Privacy-skjemaet.

## Pilot og nødstopp

Start med intern TestFlight, deretter 20–50 inviterte brukere. Følg feilrate,
synkavvisninger og supporthenvendelser minst én uke før bredere utrulling.
Backend kan stoppes uten å stoppe lokal logging. Supabase-funksjonen har en
serverstyrt kill switch som returnerer `503` og `Retry-After`, slik at hendelser
forblir lokale og retrybare. Produksjonssynk skal fortsatt ikke aktiveres før
resten av porten er dokumentert grønn.

Ved alvorlig feil: stans nye backenddeploys, deaktiver synkmottak hvis mulig,
bevar databasen og loggene, og rull tilbake applikasjonsimaget. Ikke reverser en
databasemigrasjon før konsekvensen for nyere data er kontrollert. Etter recovery
replayes ventende klienthendelser idempotent med opprinnelig `eventId`.

## Go/no-go

Offentlig produksjon er **no-go** til staging-porten er utført med faktiske
resultater. Å ha sjekklisten i repoet er ikke i seg selv godkjenning.

## Verifisering 2026-10-02 – synk og recovery

Kontrollert mot arbeidskopien med pågående porsjonsendringer, uten deploy.
Brukte skills: offline-sync, backend-api, ios-swiftui og qa-release.

- Isolert lokal Supabase (`matlogg-sync-readiness`, porter 5662x), med alle
  tre repo-migrasjoner: 69 pgTAP-tester bestod; SQL-lint uten funn.
- Deno 2.5.4: 10 kontrakttester bestod; check av alle tre Edge Functions
  og lint bestod. Serverimporter bruker eksplisitte, versjonerte npm-adresser
  slik at funksjonene også kan startes uten et separat importkart.
- Lokale HTTP-kontroller gjennom Auth → Edge Function → PostgreSQL bestod:
  autentisert kill switch, upload, replay med samme event-ID,
  kryssbrukerkollisjon, delvis batch-avvisning og ugyldig token. Bare syntetiske
  kontoer ble brukt, og lokal server-kill-switch ble satt tilbake til `false`.
- `bash scripts/verify-local-backup-restore.sh` bestod med syntetiske data.
  Logisk dump av `auth`, `public` og `private` ble gjenopprettet i en ny,
  separat database. Radkontrollsummer og antall samsvarte; SQL-restore bevarte
  skjema, RLS og grants uten feil. Skriptet er begrenset til QA-containeren.
  Dette beviser ikke hosted backup/PITR, Storage-backup, hemmeligheter,
  slettingshåndtering etter restore eller operativ recovery.
- Xcode kompilerte appen og testpakken, inkludert `SyncEngine` og
  `SyncRetryTests`. Kjøring av `SyncRetryTests`, `AuthViewModelTests`,
  `inFlightResetsToPending` og `retryBackoffSkipsUntilReady` ble forsøkt med
  `xcodebuild test`, deretter `test-without-building` på en separat iOS 26.5
  QA-simulator. CoreSimulator/testoppstart hang før testresultater og kjøringen
  ble avbrutt. iOS-testene er **ikke** bekreftet grønne og må kjøres igjen.
- Klientens delvise `SERVER_ERROR` følger nå retry/backoff. ACK kan bare
  ferdigmarkere hendelser fra sendt batch, og dupliserte avvisninger krasjer
  ikke klienten. Tester dekker også timeout med opprinnelig event-ID.

Read-only kontroll av `MatLogg Staging` viste `ACTIVE_HEALTHY`,
`sync_enabled=false` og bare migrasjon `20260928090000`. Vann- og
porsjonsmigrasjonene er ikke deployet. Tre Edge Functions er aktive, versjon 2.
Ingen staging-/produksjonsdata eller konfigurasjon ble endret.

**No-go for aktivering:** klient/server-versjonene må samordnes og staging
må gjennomføre samme ende-til-ende-port. Faktisk hosted backup/PITR og
restore, overvåkning/varsler og de øvrige pilotportene er ikke verifisert.
Arkitekturen er bevart: retry ligger ved infrastrukturgrensen, lokal atomisk
lagring og backendens eierskap/transaksjoner er uendret. Ingen arkitekturavvik.

## Oppfølging 2026-10-02 – staging-port gjennomført delvis

Dette erstatter tidligere uverifisert iOS-/staging-status ovenfor.

- Xcode/iOS 26.5 på dedikert QA-simulator: 19 auth-, 30 lagrings- og
  10 synktestkjøringer bestod (59 totalt i siste relevante suite-resultater).
  Tre eldre migrasjonstestoppsett ble rettet til å fjerne vann-tabellen før
  simulert downgrade og bruke siste schema-versjon. Produksjonsmigrasjoner
  ble ikke svekket. Retry testes med SERVER_ERROR og SYNC_DISABLED.
- Lokal Supabase: alle fire migrasjoner, 71 pgTAP-tester, SQL-lint og ny
  logisk backup/restore bestod.
- Staging hvwktobxgarxptefzwbq har alle fire migrasjonene og sync-events v3
  med JWT-verifisering bevart. Migrasjonshistorikken matcher repo-filene.
- Auth → Edge → PostgreSQL med syntetiske kontoer bestod: autentisert
  kill switch, upload, replay, kryssbrukerkollisjon, delvis batch og ugyldig
  JWT. Mottak ble kun åpnet kortvarig under testen; sync_enabled=false er
  bekreftet etterpå. Testkontoer og deres domenedata er ryddet bort.
- Direkte RPC kunne omgå Edge-nødstoppen. Migrasjon
  20261002190000_rpc_sync_kill_switch.sql håndhever nå samme kontroll før
  database-/inbox-skriving. Staging-kall med synk av gir status rejected og
  code SYNC_DISABLED. Auth, grants, eierskap, local-first og atomiske
  transaksjonsgrenser er bevart. Ingen arkitekturavvik.

Kommandoer: målrettet xcodebuild test for AuthViewModelTests, SyncRetryTests
og MatLoggTests; supabase migration up --local, supabase test db,
supabase db lint --local --schema public --schema private --level warning
og bash scripts/verify-local-backup-restore.sh. Staging ble oppdatert via
Supabase-connectoren; HTTP-testene brukte syntetiske kontoer og verifisert TLS.
Produksjon er ikke opprettet eller endret.

**No-go-punkter:** hosted backup/PITR og isolert hosted restore er ikke
bekreftet; dashboardet krever innlogging. Varsler/ansvarlig mottaker og
operativ recovery er ikke demonstrert. Fysisk iPhone er registrert, men
utilgjengelig; TestFlight, personvernporten for helsedata og separat
produksjonsmiljø gjenstår.

Security Advisor: app_config har RLS uten klientpolicy (tilsiktet sperring),
og sync-RPC har authenticated SECURITY DEFINER EXECUTE (tilsiktet med
identitets-/eierskapskontroller). Leaked-password protection er av og må
vurderes før pilot: [Supabase password security](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection).
Direkte RPC går fortsatt utenom Edge-kvoten; plattform-/databasebegrensning
må avklares og verifiseres før aktivering. Edge rate limiting alene dekker
ikke hele skriveflaten.

## Oppfølging 2026-10-03 – hosted backup og fysisk enhet

Innlogget Supabase-dashboard bekrefter at MatLogg Staging er på Free-plan,
viser «No backups», og at Free ikke inkluderer prosjektbackuper. Pro vises
fra USD 25/måned med daglige backuper beholdt i sju dager. PITR er et separat
Pro-tillegg fra USD 100/måned. Ingen abonnement eller backupinnstilling er
endret. Prisene er viste startpriser; org-plan, flere prosjekter, compute og
forbruk kan påvirke sluttsummen. Hosted restore kan ikke testes fra en
hosted backup som ikke finnes. Dette er en blocker for framtidig skybackup og krever et eksplisitt budsjettvalg;
lokal lansering tilbyr ikke serverkopi av domenedata.

Fysisk iPhone 17 er nå tilkoblet og paret, iOS 27.0, Developer Mode aktivert.
Enhetsverifisering bruker separat bundle-ID
com.nithusan.MatLogg.SyncReadinessQA for å isolere testlagring fra brukerappen.
Fysisk Xcode-kjøring av MatLoggTests og SyncRetryTests bestod: 40 tester.
Kjørte xcodebuild test mot fysisk iPhone med separat bundle-ID og eksplisitt
utviklingsteam, uten repo-endringer i signeringsoppsettet. Ingen testkall
lastet opp brukerdata, og produksjonssynk er fortsatt av. Testresultat ligger
lokalt i /tmp/MatLoggPhysicalSyncQA/Logs/Test/
Test-MatLogg-2026.10.03_07-42-45-+0200.xcresult.
Målrettet fysisk UI-test testFirstLoggingWithoutAccountAndRelaunch bestod
også: lokal logging, Angre og gjenåpning i separat QA-app. Kjørte samme
xcodebuild-oppsett med bare denne UI-testen. Resultat: 40 enhetstester + én
UI-test på fysisk iPhone, begge testkjøringer TEST SUCCEEDED. UI-resultat:
/tmp/MatLoggPhysicalSyncQA/Logs/Test/
Test-MatLogg-2026.10.03_07-45-19-+0200.xcresult.

Dette er ikke en full enhets-/TestFlight-port; låsing, nettverksbytte,
operativ varsling og hosted restore krever fortsatt egne resultater.

## Fast kontroll av strekkodedekning

Før pilot etableres et fast utvalg på 30–50 norske butikkvarer, fordelt på
meieri, brød/korn, drikke, ferdigmat, pålegg, snacks og plantebaserte varer.
Bruk faktisk strekkode fra pakken og kontroller næringsgrunnlag og enhet mot
etiketten. Test med nett og et tomt katalogcachegrunnlag; ikke slett brukerdata
for å gjøre kontrollen. Pilotansvarlig gjentar kontrollen hver måned og legger
til 5 nye varer. Dette er en manuell rutine, ikke en planlagt bakgrunnsjobb.

Før resultatene i [kontrollmalen](barcode-coverage.csv), én rad per vare og
kontrolldato. Tillatte resultater: `komplett`, `ukjent`, `ufullstendig`,
`teknisk_feil` og `avvik_mot_pakke`. Noter måleenhet og konkrete avvik. Malen
inneholder ingen ferdig kontrollerte varer; første baseline må fylles fra
faktiske pakker før pilot. Ikke før bruker-ID, skannhistorikk eller matinntak.

Rapporter komplett-treffandel, antall ukjente/ufullstendige varer, tekniske feil
og avvik separat. Tekniske feil testes på nytt før dekningen vurderes. Første
baseline brukes til å avtale pilotens dekningsmål; vi lover ikke 95 % dekning
uten måling. Ved gjentatte hull i vanlige norske varegrupper vurderes en ekstra
leverandør som en egen produktbeslutning.

## Lokal lansering: implementering og QA 2026-10-03

- App-root, shared og alternative SyncEngine-oppsett har localOnly som standard.
  Releasebygg har ingen opplastingsåpen policy; bare DEBUG-tester kan velge
  integrationTesting. Backendflagg og server-kill-switch forblir av.
- Null opplasting verifisert med transportspion for start, foreground, nett
  tilbake, manuell trigger, offline/online og kontobytte, også med flagg på.
  Ingen kølesing, in-flight/ACK/dead-letter eller retry-planlegging i lokal modus.
- Hjem, førstegangsbruk, innlogging/kontokobling og Profil forklarer lokal lagring.
  Gamle synkfeil/retry-handlinger skjules. JSON beskrives uten restore-løfte.
- Eksportens eierskap, bilder, mål-/vekt-/vann-/porsjonsdata og opprydding er testet.
  SQLite og eksportens Data Protection-attributter er verifisert på fysisk iPhone.
  Abandoned eksportfiler eldre enn 24 timer ryddes best-effort ved serviceoppstart.
- Fysisk iPhone 17/iOS 27.0, separat bundle com.nithusan.MatLogg.SyncReadinessQA:
  **76 enhetstester i seks målrettede suites, 0 feil**. Kjørte xcodebuild test
  med SyncRetryTests, ProfileTests, MatLoggTests, AuthServiceTests,
  PortionLoggingTests og WaterLoggingTests. Resultat:
  /tmp/MatLoggPhysicalSyncQA/Logs/Test/Test-MatLogg-2026.10.03_08-09-38-+0200.xcresult.
- Tre fysiske UI-flyter bestod: lokal førstegangslogging/Angre/gjenåpning,
  førstegangsbruk med AccessibilityXXXL og lokal status/eksporthandling i Profil.
  Profiltesten bestod i Test-MatLogg-2026.10.03_08-06-18-+0200.xcresult (den andre UI-testen ble deretter rettet); de to onboardingflytene bestod
  samlet i Test-MatLogg-2026.10.03_08-08-02-+0200.xcresult. Stor-tekst-feil
  ble rettet ved å flytte datatapsinformasjonen inn i den scrollbare listen.
- Simulator viste ikke iOS-beskyttelsesattributter; kontrollen ble flyttet til
  fysisk enhet. To senere simulatorbygg hang under kompilering og ble avbrutt;
  de rapporteres ikke som grønne. Endelig fysisk kontroll er grønn.
- PrivacyInfo.xcprivacy bestod plutil -lint; git diff --check er ren.

Arkitekturkontroll: policyen eies av infrastrukturen og injiseres ved roten;
AppState koordinerer tilgjengelighet, og views viser state/videresender handlinger.
Ingen ny View-IO, backend-/kontrakts-/skjemaendring eller endret auth/tilgang.
Eksisterende atomisk domeneskriving + event og eierfiltrering beholdes og testes.
Ingen nye arkitekturavvik identifisert.

Gjenstår før offentlig release: eksisterende konto-/personvern-/driftsavklaringer
og TestFlight-port. iCloud/Finder-restore på ny telefon, eierbinding uten token,
fysisk flymodus-/låseøvelse og full VoiceOver-gjennomgang er ikke utført.
Nettstatus er testet med injisert tilstand; ingen ekte helsedata ble sendt.
UI-kjøringen logger også «Invalid frame dimension» under launch; flytene bestod,
men denne visuelle runtime-advarselen skal følges opp før bred pilot.
Skykopi tilbys ikke, og ny import eller telefonrestore er ikke gjennomført.
**Go for videre lokal QA; no-go for produksjonsutrulling før aktive porter er lukket.**

## 2026-10-07 – Personvernlenke og kontosletting

Appens personvernlenke peker på `/MatLogg/personvern.html`. Kildefilen til
nettsidens erklæring og `matlogg-legal/privacy.md` er oppdatert, men nettsiden
og appen er ikke publisert som del av denne oppgaven.

Tre versjonerte migrasjoner er anvendt i MatLogg Staging: sletting av egne
produkter, opprydding av rate-limit-rader og umiddelbar RLS-lesesperring etter
sletteforespørsel. Hosted test med syntetiske kontoer demonstrerte faktisk
Auth-hard-delete og produktsletting via purge-funksjonen. En annen konto
forble urørt. Separat hosted HTTP-test viste at gammelt token mistet
lesetilgang straks etter soft-delete, mens annen aktiv konto beholdt tilgang.
Alle syntetiske testkontoer ble fjernet.

95 lokale databasekontroller og lokal HTTP-flyt bestod; db lint rapporterte
ingen skjemafeil. Legacy-backend bygget og auth-maintenance-test bestod.
Nettsidens TypeScript-kontroll og Vite-bygg bestod med Node 24.19.0.
Detaljer om iOS-kjøringene føres i `privacy-data-inventory.md`.

**No-go for produksjon:** Faktiske backup-/loggfrister, slettingshåndtering
etter restore og varsling til en konkret mottaker er ikke dokumentert her.
30-dagersfristen er beholdt, men trenger dokumentert begrunnelse.
Historiske produktbidrag uten eier-ID må vurderes separat dersom de finnes.
Publisering av app/nettside og produksjonsutrulling krever eksplisitt go/no-go.

### Oppfølging – uten fast ventetid

Ny kildekode forsøker serversletting i samme forespørsel og retry hvert femte
minutt. Den gamle 30-dagersfristen er fjernet for nye forespørsler; historiske
forespørsler endres ikke automatisk. Apptekst og begge personverntekster følger
den nye adferden og skal publiseres sammen med backend.

Tilgjengelig connector viser bare MatLogg Staging, ingen produksjonsprosjekt.
Forsøk på aktuell backupkontroll i dashboard stoppet på innloggingsskjermen;
dagens backup-/PITR- og loggfrister kan derfor ikke bekreftes. Tidligere
Free/«No backups»-observasjon er historisk, ikke ny verifisering.
Restore skal holdes uten trafikk til tidligere kontoslettinger er gjenanvendt
og eierisolasjon/sletting er kontrollert. Et separat, tilgangsbegrenset
sletteregister utenfor den restaurerte databasen og dokumentert frist for
dette må være etablert før hosted restore kan godkjennes.

Varslingsmottaker er avklart til nithusank.2002@gmail.com. E-postadapter er
klargjort; manglende avsender/API-nøkkel er fortsatt blocker for reell varsling.
Adapteren fanger funksjons-/purge-feil. Uteblitt cron eller utilgjengelig Edge
Runtime krever separat overvåking; funksjonen kan ikke varsle når den ikke kjører.
Ingen produksjonsutrulling eller nett-/app-publisering er utført.

**Go for staging:** migrasjon og Edge Functions er utrullet; cron kjører
hvert femte minutt. Hosted syntetisk konto ble hard-deletet sammen med egne
produkter i samme forespørsel. Lokal HTTP-flyt og retry, 95 SQL-kontroller,
15 Deno-tester, lint og backend-/nettbygg bestod.
**No-go for produksjon:** tilgang til produksjonsprosjekt, faktisk
backup-/logglagring og restore-prosedyre, aktiverte og leveransetestede varsler
samt separat overvåking av uteblitte kjøringer gjenstår. Varslingsmottaker er
avklart; begrunnelse for gammel 30-dagersfrist er ikke lenger relevant for
nye forespørsler.

## Fysisk kandidatkontroll 2026-10-08

Kandidat fra commit `4a749fa` i separat QA-app
`com.nithusan.MatLogg.QA1008.MatLogg`, fysisk iPhone 17 / iOS 27.0
(24A435). Kildekopi, hashmanifest, bygg-/testlogger og xcresult er bevart i
`/Users/nithu/MatLogg-QA/2026-10-08-physical/`. Apple-entitlement er beholdt.
Hashkontroll mot arbeidsområdet viser bare avvik i Xcodes brukergrensesnittstate;
klientkode, konfigurasjon og tester samsvarer.

- Første `build-for-testing` feilet fordi Mac-en gikk tom for diskplass.
  Etter frigjort plass bestod samme bygg ved nytt forsøk.
- `test-without-building` med `ProfileTests`, `PortionLoggingTests`,
  `PortionImportTests`, `LoggingDraftTests` og `RepeatFoodTests`:
  **47 tester bestod, 0 feil, 0 hoppet over** (52 kjøringer med parameterisering).
- Samlet `test-without-building` for kritiske UI-flyter:
  **11 tester bestod, 0 feil, 0 hoppet over**. Dekker første logging/omstart,
  intro med stor tekst, lokal lagringsinformasjon, manuell registrering og
  redigering på tidligere dato, porsjoner etter omstart/redigering,
  gjenlogging/Angre, vannlogging og tre utkastgjenopprettingsflyter.
  Utkastflyten med største tekststørrelse og automatisk tilgjengelighetsaudit
  bestod; dette erstatter ikke manuell VoiceOver. Termineringstesten
  beviser ikke gjenoppretting innen autosave-vinduet på 300 ms.
- Seks runtime-advarsler om `Invalid frame dimension (negative or non-finite)`
  er registrert i UI-resultatet; ingen testfeil eller krasj i denne kjøringen.

Kommandoene brukte scheme `MatLogg`, fysisk device-destination, eget
DerivedData og `-parallel-testing-enabled NO`. Testantall og resultat er
kontrollert med `xcresulttool get test-results summary`; kommandoenes
exit-status alene er ikke brukt som bevis.

**Go for videre intern QA; ekstern pilot er fortsatt ikke godkjent.**
Ekte Apple-innlogging/kontokobling/utlogging, kamera-/etikettbaseline,
manuell VoiceOver og faktisk offline-/låsekontroll av denne kandidaten er
ikke utført. Tidligere manuell offlinekontroll gjelder kandidaten fra 7. oktober.
Konto-/personvern-/driftsporter og forståelses-/frafallsobservasjoner er heller
ikke lukket av disse testene. Dette er et signert Debug-testbygg, ikke
verifisering av et TestFlight-distribusjonsbygg.

Skills: `ios-swiftui` og `qa-release`. Kun denne statusdokumentasjonen er
endret; ingen endring i avhengighetsretning, IO, local-first, transaksjonsgrenser,
eierskap eller synkkontrakt.

### Utvidet fysisk QA 2026-10-08

Samme signerte QA-kandidat og fysisk iPhone som over, uten endringer i app
eller tester. `test-without-building`, scheme `MatLogg`, eksplisitt fysisk
destination og `-parallel-testing-enabled NO`. Resultatene er kontrollert
med `xcresulttool get test-results summary`.

- `ExtendedStorage.xcresult`: **64 tester bestod, 0 feil, 0 hoppet over**
  (81 kjøringer med parameterisering) i `DailyGoalsTests`, `SavedMealsTests`,
  `SavedMealStorageTests`, `MealReuseTests` og `ProfileTests`. Dekker blant annet
  målvalidering/bevaring, måltidsgjenbruk, lagrede måltider og lokal
  eksport/sletting med eierisolasjon. ProfileTests ble gjentatt fra første runde;
  testantallene skal derfor ikke summeres som unik dekning. Dette er
  repository-/ViewModel-tester, ikke manuell kontroll av systemets delingsark
  eller ekte kontosletting.
- `ExtendedUI.xcresult`: **6 bestod, 1 feilet, 0 hoppet over**. Grønne flyter:
  egendefinerte mål etter lagring/omstart, ugyldig input/Avbryt, eksplisitt
  godkjenning av forslag, eldre launch-argumenter, inngang til lagrede måltider
  og lokalt søk/produktåpning. Måltidsbibliotekets UI-test kontrollerer
  oppdagbarhet; full opprettelse/redigering/sletting i UI er ikke testet her.
- `DailyGoalsUITests/testLargeTextKeepsFieldsAndSaveReachable` feilet i
  `openGoals` ved forventning om navigation bar «Daglige mål».
  `LargeGoalsRetest.xcresult`: uendret test alene feilet på samme punkt
  (0 bestod, 1 feilet). Appen endte på «Utvikling» etter trykk på
  `profile-edit-goals`, dokumentert i eksportert UI-hierarki. Mulig
  treffpunkt/overlapp ved bunnmenyen; appfeil versus automatiseringsfeil er
  ikke avklart. Behandles som åpent QA-funn, ikke som bestått målskjerm.
- Dimensjonsadvarselen er reprodusert tre ganger i den utvidede UI-kjøringen.
  Målrettet gjennomgang av frame-uttrykk og xcresult-issues ga ingen sikker
  årsak eller kildekodelinje. Ingen krasj; ingen rettelse utført.

Logger, xcresult og eksporterte UI-hierarkier ligger i samme QA-mappe.
**No-go for ekstern pilot består.** Avklar stor-tekstnavigasjon før denne
flyten godkjennes, og følg opp dimensjonsadvarselen. Øvrige tidligere åpne
porter er uendret. Kun statusdokumentasjon er endret; ingen arkitekturavvik.
Skills: `ios-swiftui`, `nutrition-privacy`, `qa-release`.

### Oppfølging av stor-tekstnavigasjon 2026-10-08

`DailyGoalsUITests.openGoals` ruller nå målraden helt over bunnmenyen
før trykk, og kontrollerer både `isHittable` og radens plassering. Gesten
går innenfor profilinnholdet, utenfor bunnmenyen. Testens forventninger om
åpnet målskjerm, tilgjengelige felt og lagring er beholdt. Ingen appkode
er endret; tidligere feil peker mot testens treffpunkt på delvis dekket rad.

`xcodebuild test` på samme separate QA-app / fysisk iPhone 17, iOS 27.0:
**alle 5 DailyGoalsUITests bestod, 0 feil, 0 hoppet over**, inkludert
`testLargeTextKeepsFieldsAndSaveReachable`. Resultatet er kontrollert med
xcresulttool; `GoalsNavigationFix.xcresult`, logg og skjermbilder ligger i
den eksisterende QA-mappen. Skjermbildet av lagringsområdet med stor tekst
er visuelt kontrollert. Deler av lagreknappen ligger bak menyen i dette
snapshotet; testen bekrefter vellykket trykk/lagring, ikke full synlighet av
hele knappen samtidig. Manuell VoiceOver/full visuell tilgjengelighetskontroll
er derfor fortsatt en separat port.

Det konkrete automatiserte navigasjonsfunnet er lukket for den korrigerte
testinteraksjonen. To dimensjonsadvarsler forekommer fortsatt; årsaken er
uavklart. Øvrige pilotporter og no-go er uendret. `git diff --check` bestod.
Skills: product-design, ios-swiftui, qa-release. Arkitekturkontroll:
kun testinteraksjon/dokumentasjon endret; ingen påvirkning på MVVM, IO,
local-first, transaksjoner eller eierskap.

### Full synlighet av lagreknapp ved største tekststørrelse – 2026-10-08

UI-testen krever nå at hele lagreknappen ligger over den faktiske
bunnmenyen før lagring. Fanebytte i testhjelperen ruller eksplisitt Profil
inn i den horisontale menyen før trykk. Første kjøring
(`FullSaveVisibility.xcresult`) feilet fordi Profil-trykket lot appen bli
på Hjem, før målskjermen. Etter eksplisitt fanerulling bestod
`FullSaveVisibilityRetry.xcresult`: **1 test, 0 feil, 0 hoppet over**,
på samme fysiske iPhone og uendret appkode. Resultatet er kontrollert
med xcresulttool og skjermbildet visuelt: hele «Lagre endringer» ligger
fritt over menyen. Lagring og bekreftelse bestod.

Tidligere delvis skjult knapp i screenshot skyldtes at testen sluttet
å rulle ved `isHittable`; en fast appoverlapping er ikke bekreftet.
Kun testinteraksjonen er rettet, ingen produkt-/layoutendring.

Dimensjonsadvarselen er lokalisert i eksisterende logg til overgangen
fra intro til første søk. Målrettet gjennomgang av onboarding og frame-
uttrykk gir fortsatt ingen bevist årsak. Den siste testen, som starter
med lokal debugprofil uten intro, hadde ingen runtime-advarsler; det
lukker ikke onboarding-funnet. Ingen spekulativ apprettelse er utført.
Dette punktet er fortsatt uferdig og krever videre diagnose av introovergangen.

`git diff --check` bestod. Skills: product-design, ios-swiftui, qa-release.
Kun tester og dokumentasjon endret; ingen arkitekturavvik eller endret IO,
lagring, ernæringsberegning eller databruk. Pilotens øvrige no-go består.

### Debuggerforsøk på introovergangen – 2026-10-08

LLDB ble koblet til separat fysisk QA-app med stoppunkt på runtime-logging.
Flere prosesser mistet forbindelsen med «Resume timed out»; ny debuggerøkt
fikk kjøre etter at brukeren bekreftet opplåst telefon/kabel. En midlertidig
QA-only task utløste `flow.startLogging()` etter åtte sekunder. Også en
separat tom diagnoseapp ble brukt for å unngå tidligere onboarding-status.
Ingen brukbar kallstakk for dimensjonsadvarselen ble fanget. Automatisk
overgang ved direkte devicectl/LLDB-launch reproduserte ikke det observerte
UI-testfunnet; dette er ikke bevis for at advarselen er borte.

Diagnoseendringen er fjernet fra kildekopien, debuggeren er frakoblet og
ordinær QA-app er bygget/installert igjen. Diagnoseappen har separat
bundle-ID `com.nithusan.MatLogg.Diagnose1008.MatLogg`; ingen ekte brukerdata
er berørt. Ingen diagnosekode lagt i repo eller layoutrettelse utført.
Dimensjonsfunnet er fortsatt åpent. Neste diagnose må fange samme
UI-testutløste overgang med testens runtime-diagnostikk aktiv.

### Dimensjonsadvarsel: årsak fanget og søk rettet – 2026-10-08

Oppfølging erstatter det tidligere uavklarte funnet for intro → søk.
LLDB koblet til den faktisk UI-teststartede appen før introovergangen.
Stopp på `os_log_fault_default_callback` fanget kallstakken via
`XCTAutomationSupport.runtime_issue_os_log_fault_callback`,
`SwiftUICore._FrameLayout.init` og **SwiftUI.InputAccessoryBar.body**.
Utdrag bevart som `runtime-backtrace.txt` i QA-mappen.
Dette lokaliserer advarselen til systemets tastaturverktøylinje, ikke
MatLoggs bunnmeny. Den interne ugyldige dimensjonens verdi er ikke målt.

Å fjerne Spacer alene beholdt advarselen (`KeyboardToolbarCandidate`).
Søkets «Ferdig» er derfor flyttet fra keyboard-toolbar til navigasjonslinjen
mens søkefeltet har fokus. Samme handling fjerner fokus; søk/lagring og
databruk er uendret. Ingen globale runtime-varsler er deaktivert.

- `SearchDismissCandidate.xcresult`: **3 UI-tester bestod, ingen
  runtime-advarsler**, inkludert stor tekst og intro → første logging.
- `SearchDismissFinal.xcresult`: **2 UI-tester bestod, ingen
  runtime-advarsler**. Første logging kontrollerer nå eksplisitt at «Ferdig»
  lukker tastaturet og at feltet kan fokuseres igjen før søk/logging/omstart.
  Ordinær Søk-fane/produktåpning er også grønn.
- Testantall/advarsler er kontrollert med xcresulttool, fysisk iPhone 17
  / iOS 27.0. `xcodebuild test`, eget QA-bygg og serial testing.
- Første diagnosekjøring feilet under runner-oppstart; den regnes ikke som
  bestått. Midlertidig 35-sekunders pause for debugger-attach er fjernet fra
  QA-testkopien og finnes ikke i repoet.

Aksept: Tastaturet kan lukkes eksplisitt, søk kan gjenopptas, og den
reproduserte introovergangen gir ikke dimensjonsadvarsel i de målrettede
testene. Andre skjermers keyboard-toolbars er ikke vurdert som rettet.
Pilotens konto-, kamera-, offline-, VoiceOver- og driftsporter gjenstår.
Skills: product-design, ios-swiftui, qa-release. Arkitekturkontroll:
kun view-lokal fokus/UI og regresjonstest endret; ingen ny IO, featurelogikk
i AppState, endret local-first, transaksjon, eierskap eller synkkontrakt.
`git diff --check` bestod.

### Ekte Apple-forsøk i QA-app – 2026-10-08

Brukerens fysiske forsøk viste «Kontohandlingen kunne ikke fullføres».
Read-only staging Auth-logg for 16:40–16:50 UTC bekrefter HTTP 400:
`Unacceptable audience in id_token: [com.nithusan.MatLogg.QA1008.MatLogg]`
ved 16:44:02 UTC. Ingen kontoidentifikator, token eller nettverksadresse
er kopiert til repoet. Apple-token kom fram til Supabase, men QA-bundle-ID
var ikke tillatt av provideroppsettet. Kontokobling/utlogging kunne derfor
ikke verifiseres i dette forsøket. Dette er ikke en bekreftet feil for vanlig distribusjons-ID.

Etter eksplisitt brukergodkjenning ble Apple-providerens Client IDs i
MatLogg Staging 2026-10-08 utvidet til
`com.nithusan.MatLogg,com.nithusan.MatLogg.QA1008.MatLogg`.
Dashboardet bekreftet lagring, og gjenåpnet innstilling viste begge ID-er.
Øvrige providerinnstillinger ble beholdt.

Nytt fysisk forsøk nådde dialogen for kontokobling; brukerens skjermbilde
viste én lokal loggføring. Etter «Knytt til konto» bekreftet brukeren at
samme loggføring fortsatt viste riktig mengde. Brukeren bekreftet deretter
alle tre kontroller: loggføringen bestod full lukking og gjenåpning av appen,
kontodata var ikke synlige i lokal profil etter utlogging, og samme
loggføring kom tilbake med riktig mengde etter innlogging med samme
Apple-konto. Denne manuelle kontoflyten er bestått i QA-app mot staging.
Resultatet er brukerobservert; det dekker ikke TestFlight/produksjon,
en annen konto eller skybackup/synk.

### Intern TestFlight-kandidat – 2026-10-08

Release-arkiv og App Store Connect-eksport bestod med vanlig bundle-ID
`com.nithusan.MatLogg`, versjon 1.0 og bygg 2026100801. Arkivet inkluderer
den fysisk testede rettelsen for tastaturlukking i søk. Release manglet lokal
Supabase-konfigurasjon; kandidaten ble derfor bygget med eksplisitt
`-xcconfig Config/Supabase-Debug.xcconfig` mot MatLogg Staging.
Ferdig Info.plist ble kontrollert for bundle-ID, versjon, byggnummer og
staging-konfigurasjon uten utskrift av nøkkelen. Domenesynk er fortsatt av,
og app-roten bruker `localOnly`. Ingen backend eller migrasjoner ble endret.

`xcodebuild archive` og `xcodebuild -exportArchive` (først lokal eksport,
deretter destination upload) bestod. App Store Connect bekreftet
«Upload succeeded» og behandling startet kl. 18:58 Oslo. Dette bekrefter
opplasting, ikke ferdig behandling eller tilgjengelighet for testere.
Arkiv, IPA, logger og kandidatmanifest med SHA-256 ligger utenfor repoet i
`/Users/nithu/MatLogg-QA/2026-10-08-testflight/`.

Go for videre intern TestFlight-QA når Apple har behandlet kandidaten.
Ekstern testing og produksjon er fortsatt ikke godkjent. Neste kontroll på
dette bygget: ekte Apple-innlogging/kontokobling, logging i flymodus og
bevaring etter omstart, søk/tastaturlukking og stor tekst. Tidligere grønne
tester ble ikke kjørt på nytt fordi appkoden var uendret etter fysisk QA;
distribusjonsbygget krever egne manuelle observasjoner. Arkitekturkontroll:
ingen endret avhengighetsretning, IO-grense, lokal transaksjon eller eierskap.
Skills: ios-swiftui og qa-release. `git diff --check` bestod.

### Brukerbekreftet TestFlight-kontroll – 2026-10-08

Brukeren bekreftet installasjon gjennom TestFlight etter opplastingen av
1.0 (2026100801), og rapporterte at alle fire avtalte kontroller bestod:

- Logging med flymodus og Wi-Fi av; mengden bestod full lukking og gjenåpning.
- Søk, «Ferdig» for tastaturlukking og logging fra søkeresultat fungerte.
- Apple-innlogging, eventuell kontokobling og ut-/innlogging bevarte loggen.
- Stor tekst: Profil → Daglige mål kunne åpnes og lagres med tilgjengelig knapp.

Dette er brukerobserverte manuelle resultater. Byggnummeret på den installerte
appen ble ikke separat bekreftet; kandidaten over er antatt installert ut fra
testforløpet. Ingen nye automatiske tester eller kodeendringer var nødvendige
for denne dokumentasjonsoppdateringen. Intern TestFlight-røyketest er bestått;
det er ikke samlet godkjenning av ekstern pilot eller produksjon. Resterende
akseptkrav øverst gjelder fortsatt, inkludert skanning, manuell registrering,
næringssummer, redigering/sletting/Angre og eksport på kandidatbygget samt
konto-/personvern- og driftsavklaringer. Neste steg er å lukke disse hullene
før en eksplisitt go/no-go for ekstern testing. Skill brukt: qa-release.

### Supplerende fysisk automatisert QA – 2026-10-08

TestFlight-appen ble ikke erstattet. Fysiske UI-tester kjørte på isolerte
QA-ID-er, samme appkode som kandidaten, uten Apple-entitlement i de nye
testinstallasjonene. `RemainingCleanFlows.xcresult` bekrefter bestått
førstegangslogging/Angre/gjenåpning og manuell registrering/direkte redigering
med flytting til annet måltid på tidligere dato. Første kjøring på den
innloggede QA-appen feilet onboardingforventninger; ren installasjon løste det.

Søkets manuelle reserveflyt feilet en gammel forventning om knappeteksten
«Legg til …». Eksportert UI-hierarki viste korrekt «Velg mengde», produktnavn,
100 g og `logging-draft-save`. Testen i `MatLoggUITests/MatLoggUITests.swift`
ble oppdatert til denne stabile ID-en og 15 sekunders overgangsfrist;
5 sekunder var ikke tilstrekkelig i retest. Et gjenbrukt, bevart utkast ga
også en feil før produktregistrering. Ren installasjon med oppdatert test
bestod i `ManualFallbackWaitRetest.xcresult` (én test, null feil).
Dette lukker funksjonskontrollen på QA-kandidaten, men den korte
overgangsfristens ustabilitet er ikke dokumentert som en ytelsesfeil eller
løst appfeil. Appkode og opplastet TestFlight-bygg er uendret.

Eksport-/eierskaps-/porsjonslogikk støttes av tidligere grønne målrettede
resultater; disse ble ikke gjentatt uten kodeendring. Ekte vare/etikett,
eksport via delingsarket og øvrige manglende TestFlight-observasjoner er
fortsatt åpne. Supabase-DPA, SMTP-leverandør og relevante driftsfrister er
fortsatt uavklart i datakartet; automatiserte app-tester lukker ikke disse.
No-go for ekstern pilot består. Skills: qa-release, ios-swiftui,
nutrition-privacy. Kun test og dokumentasjon endret; ingen nye IO-grenser,
endret local-first, eierskap eller transaksjoner. `git diff --check` bestod.

Brukeren bekreftet deretter at ekte vareskanning i TestFlight fungerte,
at navn og næringsverdier ble kontrollert mot etiketten, og at en kjent
mengde kunne logges. Dette er brukerobservert bestått for én vare;
vare/GTIN og konkrete etikettverdier ble ikke oppgitt. Resultatet lukker
denne enkle skannkontrollen, ikke en bred strekkode-/datakvalitetsbaseline.
Brukeren leverte deretter eksportfilen fra den avtalte TestFlight-kontrollen.
Lokal JSON-parsing bestod: schema-versjon 2, to loggføringer og to
skannhistorikkposter. Begge loggføringer hadde positive, endelige mengder,
enhet og dato samt ikke-negative, endelige kalori-/makroverdier. Dette
bekrefter en lesbar eksport med loggdata; eksakt samsvar med appens verdier
ble ikke kontrollert uten en uavhengig fasit. Ingen personopplysninger eller
filinnhold er kopiert til repoet. De øvrige åpne pilotkravene gjenstår.

### Konto- og driftsport for ekstern TestFlight – 2026-10-08

**No-go for ekstern pilot; go for fortsatt intern QA.** TestFlight-resultatene
ovenfor er grønne for de gjennomførte kontrollene, men leverandør-/driftsporten
kan ikke godkjennes ut fra disse.

Supabase-connectoren bekreftet at MatLogg Staging er `ACTIVE_HEALTHY` i
`eu-north-1`. Kandidatens staging-konfigurasjon er tidligere kontrollert i
arkivet. Dette bekrefter miljø og region, ikke avtaler eller overføringsgrunnlag.
Dashboardåpning i Chrome feilet med timeout to ganger; faktisk SMTP-oppsett,
organisasjonens avtaledokumenter og gjeldende logg-/backupfrister kunne ikke
kontrolleres. Ingen konfigurasjon, avtaler eller produksjonsdata ble endret.

Gjeldende primærkilder ble kontrollert:

- [Supabase DPA](https://supabase.com/legal/customer-resources/data-processing-addendum)
  beskriver avtalen som del av tjenestevilkårene. Dokumentet alene bekrefter
  ikke kundens gjeldende avtalegrunnlag; ukjent aksept er ikke bevis på manglende DPA.
- [Auth SMTP](https://supabase.com/docs/guides/auth/auth-smtp) begrenser standard
  e-posttjeneste til organisasjonsmedlemmer. Ekstern e-postregistrering og
  passordgjenoppretting trenger dokumentert eget SMTP-oppsett og leveringstest.
- [Auth audit logs](https://supabase.com/docs/guides/auth/audit-logs) skiller
  plattformlogger fra valgfrie databasebaserte audit-logger. Frister må
  kontrolleres for begge; generelle plangrenser er ikke dokumentasjon på
  faktisk sletting i prosjektet.

Neste steg: få dashboardtilgang til organisasjonens avtaledokumenter,
Auth-e-post/SMTP og planens logg-/backupinnstillinger. Dokumenter faktisk
leverandør og frister uten hemmeligheter. Dersom SMTP ikke er konfigurert,
krever valg/opprettelse av leverandør og auth-konfigurasjonsendring separat
avklaring. Risiko-/DPIA-beslutning og øvrige åpne akseptkrav i datakartet
består. Ingen ekstern testerinvitasjon er sendt. Skills: backend-api,
nutrition-privacy og qa-release. Verifisering: read-only prosjektliste,
leverandørdokumentasjon og `git diff --check`; ingen build nødvendig for
statusdokumentasjon. Ingen arkitekturendring.

Oppfølging etter at brukeren åpnet dashboardet: prosjektoversikten kunne
leses og bekreftet Free-plan, North EU (Stockholm), Healthy og «LAST BACKUP
No backups». Det siste er ingen bekreftelse på at alle leverandørkopier er
fraværende. Ved navigasjon mistet nettleserverktøyet forbindelsen. Direkte
Chrome-kontroll og omlasting viste deretter tomt sideinnhold på både Auth og
organisasjonssiden. SMTP, avtaledokumenter og loggfrister er fortsatt ikke
verifisert. Ingen innstillinger endret; ekstern pilot er fortsatt no-go.

Brukerens skjermbilde av MatLogg Staging → Authentication → Emails → SMTP
Settings bekrefter 2026-10-08 at «Enable custom SMTP» er deaktivert.
SMTP-status er dermed avklart: eget SMTP er ikke aktivert. Ekstern
 e-postregistrering/passordgjenoppretting kan ikke godkjennes med dette
oppsettet, gitt standardtjenestens mottakerbegrensning. Apple-flyten er
separat og har bestått tidligere kontroller; dette lukker ikke øvrige
pilotkrav. Neste steg er å avklare eksisterende SMTP-leverandør eller velge
leverandør, verifisere avsenderdomene og dokumentere avtale/frister før
konfigurasjonsendring og leveringstest. Ingen innstillinger er endret.

### Apple-only-pilotbygg – 2026-10-08

Brukeren godkjente pilotavgrensning til lokal bruk og Apple-innlogging.
`FeatureFlags.emailAuthenticationEnabled = false` skjuler e-postfelter,
passordfelt, e-postinnlogging, registreringslenke og tilhørende skille i
LoginView. E-postimplementasjonen beholdes; ingen backend/provider endres.
Dette fjerner e-postflyten fra kandidatens UI, ikke fra Supabase API.
Eksisterende e-postkontoer må derfor tas hensyn til ved senere bred utrulling.

Fysisk `PilotAppleOnlyFresh.xcresult`: én UI-test bestod, null feil.
Kontrollen åpner Konto fra førstegangslogging, bekrefter Apple-knappen og
fravær av alle e-posthandlinger. Første testforsøk kjørte null tester og
regnes ikke som bestått; neste stoppet ved installasjon av runner. Kjøring
med separat DerivedData ga faktisk testresultat. Ny ekte Apple-autentisering
ble ikke gjentatt; knappehåndtering og auth-tjenester er uendret.

Release-arkiv og opplasting bestod for 1.0 (2026100802), vanlig bundle-ID
`com.nithusan.MatLogg`, mot MatLogg Staging med eksplisitt xcconfig som
forrige kandidat. Arkivets Info.plist bekreftet ID, versjon, bygg og staging.
App Store Connect bekreftet «Upload succeeded» og processing kl. 19:33 Oslo.
Artefakter og kandidatmanifest ligger utenfor repoet i
`/Users/nithu/MatLogg-QA/2026-10-08-testflight-apple-only/`.

Go for intern QA av dette bygget. Før videre pilot: installer 2026100802 i
TestFlight og bekreft Apple-only-kontoskjermen. DPA, leverandør-/driftsfrister
og øvrige åpne pilotkrav består; SMTP er utsatt sammen med e-postflyten.
Skills: product-review, product-design, ios-swiftui, backend-api,
nutrition-privacy og qa-release. Arkitekturkontroll: endringen styrer bare
UI-tilgjengelighet; ingen ny IO, endret avhengighetsretning, eierskap,
transaksjon, local-first eller synkkontrakt. Ingen arkitekturavvik.
`git diff --check` bestod; ingen backendbuild nødvendig uten backendendring.

Brukeren bekreftet etter oppdateringsinstruksen at kontoskjermen i TestFlight
bare tilbyr Apple. Pilotens UI-avgrensning er dermed brukerbekreftet.
Installert byggnummer ble ikke separat oppgitt; 2026100802 er antatt ut fra
forløpet. Dette bekrefter skjermen, ikke en ny Apple-autentisering eller
samlet pilotgodkjenning. Kun dokumentasjon endret; ingen ny build nødvendig.

### Avtale- og loggkontroll etter Apple-only-pilot – 2026-10-08

Organisasjonsnavigasjon i Chrome ble avbrutt av meldinger om endret appkontroll;
organisasjonens konkrete avtaledokumenter er ikke lest. Ingen avtale er
akseptert og ingen lagringsinnstilling er endret.

[Supabase Data Residency and Transfers FAQ](https://supabase.com/legal/privacy-resources/data-residency-and-transfers-faq)
oppgir at Customer Data slettes innen 30 dager etter prosjektsletting.
Dette er leverandørens regel for hele prosjektet, ikke fristen for sletting
av én MatLogg-konto. Appens testede kontosletting forsøker hard-delete i samme
kall med varig retry ved feil, som dokumentert over.

[Supabase MAU-veiledning](https://supabase.com/docs/guides/troubleshooting/check-usage-for-monthly-active-users-mau-MwZaBs)
beskriver tilgang til siste dags logger på Free-plan. Dette er et
synlighetsvindu, ikke tilstrekkelig bevis for full sletting av alle kopier.
[Auth Audit Logs](https://supabase.com/docs/guides/auth/audit-logs) beskriver
separat valgfri lagring i `auth.audit_log_entries`. Aktiv innstilling og
sletterutine for denne tabellen må kontrolleres separat.

Neste konkrete bevis: organisasjon → dokumenter/DPA-status og Auth → Audit
Logs-innstilling. Ingen antakelse om signert DPA eller automatisk sletting
av databasebaserte audit-logger. Ekstern pilot er fortsatt no-go; intern
QA kan fortsette. Kun dokumentasjon; `git diff --check` bestod.

Brukerens skjermbilde 2026-10-08 av MatLogg Staging → Authentication →
Audit Logs viser «Write audit logs to the database» deaktivert. Nåværende
innstilling for databasebasert audit-logging er dermed bekreftet av.
Dette beviser ikke at eldre poster i `auth.audit_log_entries` er fjernet,
eller at plattformens Auth-logger er deaktivert. Ingen innstilling endret.
Organisasjonens konkrete DPA-status er fortsatt ikke verifisert.
Dokumentasjonsoppdatering; `git diff --check` bestod.


## Leverandørkontroll 8. oktober 2026 – standardvilkår

[Supabase Terms of Service](https://supabase.com/terms) blir effektive ved
aksept eller bruk av tjenesten og inkluderer gjeldende DPA.
[DPA, versjon 1 av 1. august 2026](https://supabase.com/legal/customer-resources/data-processing-addendum)
punkt 11.2 angir sletting av dekkede data etter en 30 dagers periode ved
avtalens utløp. Dette er ikke en slettefrist for individuelle appkontoer.
Vurderingen forutsetter vanlig nettpåmelding under standardvilkår; en særavtale
kan ha andre bestemmelser. En separat signert DPA er derfor ikke et eget
pilotkrav ut fra de kontrollerte standardvilkårene. Tidligere formuleringer om
uavklart DPA-status skal leses med denne presiseringen.

[Underleverandørlisten av 1. juni 2026](https://supabase.com/legal/subprocessor-list/June-1-2026.pdf)
er kontrollert. Den omfatter blant annet AWS og Cloudflare (hosting),
Sentry og Braintrust (overvåking), samt støtte-, analyse- og AI-tjenester.
Listen alene beviser ikke at hver tjeneste mottar MatLogg-appbrukeres data.
Stockholm-regionen beviser heller ikke at all behandling skjer i EØS:
DPA punkt 6.1 åpner for behandling andre steder, og punkt 12/Schedule 2
beskriver SCC-er. Faktiske dataflyter og overføringsvurdering gjenstår.

Brukerskjermbildet bekrefter databasebasert Auth-audit av; Supabases
[Auth-dokumentasjon](https://supabase.com/docs/guides/auth/audit-logs)
bekrefter at plattformlogger er en separat lagringsvei. Historiske poster og
full lagringstid for driftslogger er ikke verifisert. Ingen avtale akseptert,
abonnement opprettet, innstilling endret eller data slettet i denne kontrollen.

Ekstern pilot er fortsatt no-go inntil de øvrige dokumenterte personvern- og
releaseportene er avklart. Neste leverandørkontroll er aggregert kontroll av
eldre audit-poster og dokumentasjon fra Supabase av driftsloggenes lagring og
sletting. Egen auth-SMTP er utsatt sammen med e-postinnlogging.
Skill: nutrition-privacy (tidligere releasevurdering: qa-release).
Kun dokumentasjon; ingen ny kodeverifisering nødvendig.

### Oppfølging: database-audit og driftslogger 8. oktober 2026

Read-only SQL mot MatLogg Staging (`hvwktobxgarxptefzwbq`):
`SELECT count(*) AS audit_row_count FROM auth.audit_log_entries;`
returnerte **0**. Sammen med deaktivert database-audit er kontrollen av
historiske databaseposter lukket for dette tidspunktet. Ingen rå logger,
persondata eller tokens hentet; ingen sletting eller innstillingsendring.

[Supabases Data Residency and Transfers FAQ](https://supabase.com/legal/privacy-resources/data-residency-and-transfers-faq)
oppgir operasjonelle/sikkerhetsmessige formål for logger og telemetri, men
henviser til `privacy@supabase.io` for konkrete frister. FAQ-innholdet ble
tilgjengelig via nettsøk; direkte sideåpning feilet. Et tilgjengelighetsvindu
i dashboardet beviser fortsatt ikke sletting av alle leverandørkopier.
Full loggretensjon kan derfor ikke lukkes med offentlig dokumentasjon alene.

Forespørsel klar for behandlingsansvarlig å sende til `privacy@supabase.io`:

> We use hosted Supabase on the Free plan in eu-north-1 for an Apple-only
> iOS pilot. Auth audit writes to the database are disabled and the audit
> table is empty. Please confirm the retention and deletion periods for
> Auth/API/Edge Function logs and related telemetry, including any copies
> retained for security or backup purposes. Does deleting an individual
> Auth user delete or anonymize their identifiers in these logs? Please
> also confirm where these logs are processed and stored, and which
> subprocessors receive them.

Forespørselen er utarbeidet, **ikke sendt**. Brukeren har autorisert
undersøkelsen, men har ikke gitt eksplisitt instruks om å sende e-post.
Ekstern pilotstatus er uendret; database-audit er ikke lenger et åpent funn.
Skills: backend-api, nutrition-privacy og qa-release. Verifisering:
read-only aggregat i staging; dokumentasjonskontroll med `git diff --check`.

Brukeravklaring 8. oktober 2026: forespørselen til Supabases personvernkontakt
skal ikke sendes. Leverandørens fulle loggretensjon forblir uavklart; dette
er ikke bevis på manglende sletting eller et selvstendig dokumentert
releaseavvik. E-post er ikke et påkrevd neste steg. Øvrige pilotporter
må vurderes separat før go/no-go.
