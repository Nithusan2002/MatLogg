# Forbedringsplan: gjenoppretting av uferdig matlogging

Dato: 2026-10-07. Status: implementert; målrettede tester grønne. Fysisk QA gjenstår.

## Problem og ønsket resultat

Manuell produktregistrering og mengdevalg finnes i dag bare i minnet frem til
eksplisitt lagring. Systemterminering mister uferdig input. Produktet lagres
før mengdevalget, så et avbrudd kan etterlate et lagret produkt uten matlogg.
`product_drafts` finnes i SQLite, men brukes ikke av denne flyten.

Målet er at brukeren kan fortsette fra siste vellykkede lokale utkastlagring,
uten feil dato, feil profil eller dupliserte produkter og logger.
Dette anbefales som en avgrenset forbedring av MVP-ens eksisterende logging.
Planen gir ingen garanti for tastetrykk som ennå ikke er skrevet til disk.

## Avgrensning og foreslåtte valg

- Første leveranse dekker manuell produktregistrering og påfølgende mengdevalg,
  fra både Loggfør, søk og ukjent strekkode. Første logging bruker samme løsning.
- Ett aktivt registreringsutkast per lokal profil. Et nytt utkast skal aldri
  stille overskrive et eksisterende; tilby Fortsett eller Forkast først.
- Lagre lokalt uten nett. Utkast inngår ikke i synkkøen eller næringssummer.
- Bevar navn, rå tekstverdier, næringsgrunnlag, porsjonsnavn/-størrelse/-enhet,
  ferdig importert bilde, strekkode, valgt mengde/porsjon, måltidstype og dato.
  Ufullstendig eller ugyldig input må kunne lagres uten ernæringsvalidering.
- Bevar stabil utkast-ID, produkt-ID, planlagt logg-ID, profil-ID,
  skjema-versjon, revisjon, oppdateringstid og hvilket steg brukeren var på.
- Utkast slettes ved uttrykkelig forkasting eller fullført logging. Ikke innfør
  automatisk utløp i første leveranse. Vanlig lukking beholder utkastet.
- Andre redigeringsflyter, flere samtidige utkast og skybackup er senere scope.

## 1. Lokal modell og lagring

Opprett en versjonert `FoodLoggingDraft` og et lite repository med last,
lagre og forkast. ViewModel eier input og handlinger; repository skjuler SQLite.
Avhengigheter injiseres ved app-roten. AppState koordinerer bare at et utkast
er tilgjengelig, og views utfører ingen IO.

Vurder eksisterende `product_drafts` før gjenbruk: den er bevart for
kompatibilitet med tidligere utviklingsdata. Ikke omtolk eksisterende JSON
ukritisk. Bruk en additiv lokal migrasjon hvis en egen tabell for hele
registreringen er enklere og sikrere. Ukjent versjon eller korrupt utkast
skal gi kontrollert feil, uten å resette databasen eller overskrive originalen.

Utkastbilder kan lagres sammen med snapshotet dersom eksisterende komprimering
gir forsvarlig størrelse. Ved separat fil må skriverekkefølge og opprydding
unngå tap av siste komplette bilde. En bildeimport som ble avbrutt før lokal
lagring kan kreve nytt bildevalg.

## 2. Automatisk lagring og trygge overganger

Lagre etter omtrent 300 ms uten nye tastetrykk. Serialiser skriving og bruk
revisjoner slik at en eldre asynkron lagring ikke overskriver nyere input.
Flush ved stegskifte, vanlig lukking og bakgrunnslegging; dette supplerer
fortløpende lagring og er ikke en garanti ved brå terminering.

Gjenbruk eksisterende produkt-ID ved retry. Overgangen fra produktutfylling
til mengdevalg skal atomisk lagre produkt, eksisterende produktsynkhendelse
og oppdatert utkast med produktreferanse. Bevar nåværende source og enheter.

Endelig logging skal atomisk skrive matlogg og eksisterende synkhendelse og
fjerne utkastet. Bruk samme logg-ID ved gjentatt lagringsforsøk.
Før commit kan utkastet gjenopprettes; etter commit finnes loggen og utkastet
er borte. Forsinkede autosaves må ikke kunne gjenopprette et slettet utkast;
stopp og drener skriving før avslutning eller beskytt den med en
transaksjonelt kontrollert livssyklus/revisjon.

Ved lagringsfeil beholdes input i minnet. Vis «Kunne ikke lagre utkastet på
enheten. Prøv igjen.» Ikke vis lagringsbekreftelse før vellykket commit.

## 3. Gjenoppretting og brukerflyt

Etter at aktiv profil er kjent ved oppstart, hent bare dens utkast. Vis en
kompakt handling på Hjem og i Loggfør: «Du har en uferdig registrering», med
produktnavn og dato når tilgjengelig. «Fortsett» er primær, «Forkast» sekundær.
Ikke åpne skjemaet automatisk over innlogging eller onboarding.

Fortsett åpner riktig steg med opprinnelig dato, måltidstype og input. Ved
eldre dato vis «Registreringen gjelder [dato]» og tilby å endre dato eksplisitt.
Bekreft forkasting med «Forkaste den uferdige registreringen?». Et allerede
lagret produkt beholdes; forkasting av utkast skal ikke slette domenedata.
Endre dagens «Avbryt» til en tydelig lukkehandling som beholder utkastet.

Bruk eksisterende CardContainer, PrimaryButton, ErrorMessageView og semantiske
tokens. Støtt Dynamic Type, VoiceOver og minimum 44 punkters touchflate.
Gjenopprettede faneskjermer skal respektere bunnmenyens scroll-clearance.

## 4. Eierskap, sletting og dokumentasjon

Alle repository-operasjoner skal avgrenses til aktiv lokal profil, også uten
konto. Ved profilbytte stoppes gamle skriveoppgaver før ny profil lastes.
Integrer utkast og bilder i eksisterende profilsletting og sletting av lokale
data. Ingen rå feltverdier eller bilder i logger. Avklar eksport med eksisterende
eksportkontrakt og dokumenter om uferdige registreringer inkluderes.

Ved implementering oppdateres designflyten, prosjektstatus, datakart og
relevante spesifikasjoner. Korriger EC-21 i `07-edge-cases.md`, som i dag
beskriver UserDefaults-basert gjenoppretting som ikke finnes i denne flyten.
Dokumenter at utkast er lokal gjenoppretting, ikke backup. Vurder personverntekst
etter endelig valg av lagring og eksport. Synkkontrakt og backend trenger
ingen endring når utkast forblir lokale og eksisterende hendelser beholdes.

## 5. Målrettet verifisering og ferdigkriterier

| Kontroll | Forventet resultat |
| --- | --- |
| Ufullstendig input, desimalkomma og porsjon lagres; ny store/ViewModel opprettes | Samme råverdier, grunnlag, enheter, dato og steg gjenopprettes |
| Terminer under utfylling, offline, og åpne igjen | Siste committede utkast kan fortsettes; tap begrenses til ikke-lagrede endringer |
| Terminer før/etter produkttransaksjon og under mengdevalg | Riktig steg gjenopprettes; ingen nytt produkt ved retry |
| Avbrudd før/etter endelig loggtransaksjon | Enten utkast uten ny logg, eller én logg med én tilhørende hendelse uten utkast |
| Eldre autosave fullføres sent, eller etter Forkast/logging | Ingen tilbakerulling eller gjenoppstått utkast |
| Profilbytte, lokal profil uten konto og lokal sletting | Ingen tilgang på tvers av profiler; slettede utkast/bilder kommer ikke tilbake |
| Diskfeil, korrupt JSON og ukjent utkastversjon | Tydelig feil, eksisterende data beholdes, ingen falsk lagringsbekreftelse |
| Importert bilde og midnatt mellom økter | Lagret bilde vises og opprinnelig loggdato beholdes |

Prioriter repository-/ViewModel-tester med midlertidig SQLite og injiserte feil,
én UI-test som fyller ut, terminerer og starter appen på nytt, og en målrettet
kontroll på fysisk iPhone. UI-terminering er en modell av prosessavbrudd og
beviser ikke alle former for systemterminering. Ingen full testpakke uten grunn.

Ferdig når kontrollene består og løsningen eksplisitt er vurdert mot
`architecture-principles.md`: View → ViewModel → Repository → lokal store,
testbare IO-grenser, lokal bruk uten nett, atomiske overganger og profileierskap.
Produksjonsutrulling vurderes separat med qa-release og eksplisitt go/no-go.

## Leveringsrekkefølge

1. Modell, migrasjon, repository og tester for gjenåpning/eierskap.
2. Autosave og atomiske overganger i manuell flyt og mengdevalg.
3. Fortsett/Forkast, feiltilstander og gjenoppretting fra alle aktuelle innganger.
4. Avbruddsverifisering, personvern/sletting og oppdaterte spesifikasjoner.

## Implementasjon og verifisering 7. oktober 2026

Implementert med egen `food_logging_drafts`-tabell i lokal SQLite v8, additiv
migrasjon og JSON-skjema v1. DatabaseService implementerer et lite utkast-
repository. FoodLoggingDraftViewModel eier flyt, debounce, skriveorden og
profilavgrensning. Det eksisterende manuelle skjemaet gjenbrukes som en form
med injisert, observert ViewModel. Bilder ligger i snapshotet. Eksport har
additiv `food_logging_drafts`-kategori i v2. Ingen backend-/synkkontraktendring.

Berørte kodeområder:

- `App/FoodLoggingDraft.swift`, `Models.swift` og `MatLoggApp.swift`: modell,
  lokal dataoversikt og dependency composition.
- `Services/FoodLoggingDraftRepository.swift`, `DatabaseService.swift` og
  `LocalStore.swift`: IO-grense, migrasjon, revisjons-/eierskapskontroll,
  atomiske overganger, eksport og sletting.
- `ViewModels/FoodLoggingDraftViewModel.swift`, `ManualProductViewModel.swift`
  og manuelle innganger under `Views/Home/`: autosave, Fortsett/Forkast og
  gjenoppretting av produktutfylling/mengdevalg.
- `LoggingDraftTests.swift`, `LoggingDraftUITests.swift` og eksisterende
  migrasjonsfixture i `MatLoggTests.swift`: målrettet verifisering.
- Produktflyt, datamodell, edge cases, prosjektstatus, datakart, personverntekst,
  testveiledning og beslutningslogg er oppdatert.

Resultater:

- `xcodebuild test` på MatLogg Draft QA, iOS 26.5, med
  `-only-testing:MatLoggTests/LoggingDraftTests` og
  `-only-testing:MatLoggUITests/LoggingDraftUITests`: **grønn**.
  Ni enhetstester og én UI-test består. App og testtargets bygger.
  Resultat: `/tmp/MatLoggDraftQA/Logs/Test/Test-MatLogg-2026.10.07_12-58-28-+0200.xcresult`.
- Direkte Swift Testing-kjøring på macOS med produksjonens LocalStore og
  domenemodeller, i midlertidig `/tmp/MatLoggDraftCoreQA`: **grønn**.
  Syv lagringstester fra samme suite og eksisterende migrasjonstest består.
  Dette supplerer iOS-testene; det verifiserer ikke iOS-filbeskyttelse eller UI.
  Kommando: `xcrun swift test --package-path /tmp/MatLoggDraftCoreQA`.
- `git diff --check`: **grønn**.
- Tidligere simulatorforsøk stoppet ved oppstarts-/IPC-feil; siste kjøring
  fullførte uten feil. Ingen full testpakke er kjørt.

Arkitekturkontroll: View → ViewModel → repository → lokal store,
app-rotsinjeksjon, ingen ny featurelogikk i AppState, offline-funksjon,
atomiske domene-/hendelsesoverganger, profilavgrensning og testbare IO-grenser.
Ingen identifiserte arkitekturavvik. Eldre/sluttførte snapshots kan ikke
overskrives eller gjenopprettes av forsinket autosave.

Skills brukt: product-review, product-design, ios-swiftui, offline-sync,
backend-api (kontraktsgrense), nutrition-privacy og qa-release.

Gjenværende: fysisk iPhone var offline ved kontroll med `xctrace list devices`.
Fysisk systemterminering, bildeimport på enhet og manuell VoiceOver/stor tekst
må derfor kontrolleres før release. UI-testen modellerer prosessavbrudd,
ikke alle former for systemterminering. Siste ikke-committede endringer kan
fortsatt gå tapt i autosave-vinduet; utkast erstatter ikke backup.
Måltidsmalbygging og andre redigeringsflyter er fortsatt utenfor denne leveransen.
Ingen produksjonsutrulling er utført.


### Fysisk QA — oppfølging 7. oktober 2026

Telefonen ble tilgjengelig og paret. Egen QA-app med separat bundle-ID
`com.nithusan.MatLogg.DraftQA.MatLogg` bygget og signerte med en lokal, tom
rettighetsfil for testen av debugprofilen. Prosjektets vanlige Apple-pålogging
og signeringsoppsett er ikke endret. Første signeringsforsøk med appens vanlige
Apple-entitlement ble avvist av wildcard-profilen.

To teststarter på fysisk iPhone stoppet før selve UI-testen med
«Timed out while enabling automation mode». Fysisk verifisering er derfor
fortsatt ikke bekreftet. Resultater og logger ligger i ignorert
`build/draft-device-qa/PhysicalLocal.xcresult` og
`build/draft-device-qa/PhysicalAutomationRetry.xcresult`. Neste steg er å
holde telefonen ulåst, godta eventuell iOS-dialog om UI-testing og kjøre
LoggingDraftUITests på nytt. Simulator-/lagringstestresultatene over gjelder fortsatt.

Etter opplåsing startet UI-automatiseringen. Kjøringene `PhysicalUnlocked`,
`PhysicalFocus` og `PhysicalIsolated` nådde UI, men ga ikke en gyldig
ende-til-ende-bekreftelse. Logger viste at en annen MatLogg-QA-app overtok
skjermen. En samtidig xcodebuild-kjøring mot samme enhet ble bekreftet;
`PhysicalConfirmation` feilet også i oppsettet før inntasting. Videre kjøring
ble stanset for å unngå konkurrerende styring.
UI-testen velger nå eksplisitt Forkast-bekreftelsen fremfor bannerknappen,
og kontrollerer tastaturfokus før inntasting. Fysisk gjenoppretting er fortsatt
uverifisert. Neste steg er én isolert UI-testkjøring når telefonen er ledig.
`git diff --check` bestod etter testjusteringen.

### Fysisk QA — isolert kjøring bekreftet

7. oktober 2026 kl. 19:51 bestod `LoggingDraftUITests` på tilkoblet iPhone 17
med iOS 27.0: én test, null feil. Ingen annen xcodebuild-kjøring brukte enheten
ved oppstart. Testen fylte inn manuelle produkt-/næringsfelt, terminerte og
startet appen igjen, bekreftet gjenopprettet produktnavn, gikk videre til
mengde, lukket og terminerte igjen, gjenåpnet mengdesteget og fullførte loggingen.
Etter fullføring var utkastbanneret borte.

Kommando: `xcodebuild test-without-building` mot fysisk enhet, begrenset til
`MatLoggUITests/LoggingDraftUITests`, med parallell testing deaktivert og
samme separate QA-app som over. Resultat:
`build/draft-device-qa/PhysicalRetryNow.xcresult` (48,3 sekunder for testen).
Dette bekrefter gjenoppretting etter teststyrt prosessavbrudd på fysisk enhet;
faktisk systemterminering under minnepress, bildeimport og manuell VoiceOver
står fortsatt igjen før release. Autosave-vinduet på 300 ms gjelder fortsatt.
Ingen appkode ble endret under denne kjøringen; arkitekturvurderingen over gjelder.
Skills: ios-swiftui og qa-release. `git diff --check` bestod.

### Utvidet automatisk QA — 7. oktober 2026

Skills: ios-swiftui og qa-release. Ingen produksjonskode eller arkitektur endret.
Nye målrettede tester i LoggingDraftTests og LoggingDraftUITests:

- Fysisk iPhone 17 / iOS 27.0: UI-test med terminering rett etter inntasting,
  uten den eksplisitte autosave-ventingen, bestod (`PhysicalExtended.xcresult`).
  XCTest har IPC-forsinkelse; dette beviser ikke tapsfri lagring innen 300 ms.
- Deterministisk kontroll av den ekte databasen bekreftet at umiddelbar lesing
  etter tekstendring inneholder forrige snapshot, og at autosave senere lagrer
  endringen. Datatap i debounce-vinduet er dermed en bekreftet begrensning.
- Syntetisk UIKit-bilde gjennom faktisk bildeklargjøring, utkastlagring og ny
  database-/ViewModel-instans beholdt bildebytes, dekodbar forhåndsvisning og
  tekst. Fjerning av bildet ble også lagret. Dette er ikke en PhotosPicker-UI-test.
- Alle 11 LoggingDraftTests bestod på fysisk enhet (`PhysicalAuditDetails.xcresult`).
- Største tilgjengelighetstekst: hele gjenopprettings-/mengde-/fullføringsflyten
  kunne gjennomføres. Automatisk audit for dynamicType, textClipped,
  sufficientElementDescription og hitRegion rapporterte seks dynamicType-avvik:
  Hjem, Søk, Loggfør, Utvikling og Profil i bunnmenyen, samt Lukk i mengdesteget.
  Testen feiler eksplisitt på disse funnene etter fullført flyt. De øvrige
  valgte audit-kategoriene rapporterte ingen funn i de kontrollerte skjermbildene.
  Dette erstatter ikke manuell VoiceOver-opplesning eller full skjermdekning.
- PhotosPicker ende-til-ende ble forsøkt på dedikert simulator med repoets
  testbilde, men CoreSimulator svarte ikke under teststart, bootstatus og
  shutdown. Forsøket ble stanset; det er ingen gyldig pass/fail for bildevelgeren.
  En midlertidig, uverifisert picker-test er ikke beholdt.

Brukeren valgte bare automatisk tilgjengelighetskontroll; manuell VoiceOver
ble derfor ikke utført. Ingen release-godkjenning eller utrulling er gitt.
Neste steg: rette/vurdere audit-funnene og teste PhotosPicker når simulatoren
svarer. Faktisk systemterminering under minnepress gjenstår.
`git diff --check` bestod. Resultatmapper og logger ligger under ignorert
`build/draft-device-qa/`. Første filtrerte enhetstestforsøk kjørte null
Swift Testing-tester; de 11 ble deretter kjørt og bekreftet samlet.

### Tilgjengelighetsrettinger — fysisk QA bekreftet

7. oktober 2026: fjernet Dynamic Type-begrensningen i MatLoggTabBar.
Ved tilgjengelighetsstørrelser ruller menyen horisontalt med hele etiketter;
vanlige størrelser beholder femknappsoppsettet. Eksisterende måling av menyens
høyde og rulleklaring brukes videre. Mengdestegets Lukk bruker kryssikon,
skalerbar typografi, minst 44 × 44 pt og tilgjengelighetsnavnet Lukk.
Designdokumentet er oppdatert. Berørt kode: MatLoggTabBar,
RecoverableManualLoggingView og LoggingDraftUITests.

Fysisk iPhone 17 / iOS 27.0: `PhysicalAuditAdaptive.xcresult` bestod.
Utvidet kontroll `PhysicalAuditAllTabs.xcresult` bestod også (83,4 sekunder),
inkludert horisontal rulling til Profil og audit av begge sider av menyen,
gjenoppretting av tekst og mengdesteg samt fullføring. Ingen funn for
valgte dynamicType-, textClipped-, sufficientElementDescription- eller
hitRegion-kategorier i de kontrollerte skjermbildene. UI-testen ruller nå
Fortsett helt over bunnmenyen før trykk. Mellomliggende testkjøringer avdekket
klippet Utvikling-tekst og systemets tekstbaserte Lukk-kontroll; den endelige
implementasjonen over erstatter disse mellomløsningene.

PhotosPicker-forsøket kunne ikke gjenopptas: CoreSimulator svarte fortsatt
ikke på enhetslisten, også etter tjenesteomstart. Hengende simctl-kall fra
oppgaven ble stoppet. Bildeklargjøring, lagring og gjenoppretting har fortsatt
bestått på fysisk enhet; selve bildevelger-UI er uverifisert. Manuell VoiceOver
og faktisk minnepress/systemterminering er fortsatt utenfor bekreftet QA.
Autosave-begrensningen på 300 ms er uendret.

Skills: product-review, product-design, ios-swiftui og qa-release.
Arkitekturkontroll: kun presentasjon og målrettet UI-test endret; ingen ny IO,
domenelogikk, eierskapsregel eller transaksjonsgrense i views. Ingen
arkitekturavvik. `git diff --check` bestod. Ingen produksjonsutrulling.

### Simulatorforsøk og autosave-vurdering — 7. oktober 2026

Ny isolert testsimulator ble forsøkt via et separat simctl device-set under
ignorert `build/draft-device-qa/IsolatedDevices`. CoreSimulator svarte verken
på vanlig runtime-liste eller runtime-liste med det separate området.
En ny simulator kunne derfor ikke opprettes, og PhotosPicker-testen er fortsatt
uverifisert. Videre feilsøking krever at simulatorinfrastrukturen igjen svarer;
omstart av Macen er et praktisk neste tiltak etter at annet arbeid er lagret.
Ingen eksisterende simulator- eller brukerdata ble slettet.

Autosave-vurdering: dagens 300 ms er en debounce etter siste endring, ikke en
øvre grense på hvor mye inntasting som kan gå tapt. Kontinuerlig inntasting
utsetter lagringen videre. Å endre til 100 ms reduserer vanlig ventetid, men
løser ikke dette og øker antall skrivinger av hele JSON-snapshotet, som også
kan inneholde bildebytes.

Anbefalt neste implementering er umiddelbar første asynkrone lagring, deretter
ett nyeste ventende snapshot mens en skriving pågår, fulgt av ny skriving så
snart den forrige er ferdig. Bevar seriell repository-grense, revision-,
profil-/generasjonskontroll og flush før lukking/overganger. Ikke utfør SQLite-IO
på MainActor. Verifiser treg repository, kontinuerlig input, feil/retry,
profilbytte og discard under pågående skriving. En prosess kan fortsatt dø før
en asynkron commit; dette må ikke beskrives som garantert tapsfri lagring.

Denne oppfølgingen er vurdering og miljøkontroll; autosave-koden er ikke endret.
Ingen nye tester er kjørt, siden simulatoren ikke startet og produksjonskode
ikke ble endret. Tidligere fysiske testresultater gjelder fortsatt.
