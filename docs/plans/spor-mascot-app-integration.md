# Spor i appen – implementeringsplan og status

25. november 2026. Implementert på `codex/spor-mascot-iphone-preview`.
Brukeren godkjente implementering, fysisk testing, retting og avgrenset commit.
Ingen produksjonsutrulling er utført eller godkjent her.

## Mål og scope

Gi Spor Mat et varmt, gjenkjennelig ansikt uten å gjøre logging tregere eller
la figuren evaluere mat, kalorier, vekt eller aktivitet.

| Flate | Utforming og adferd |
| --- | --- |
| Eksisterende introduksjon | Stor Spor erstatter illustrasjonen. Første side kan spille én kort hilsen per visningslevetid; eksisterende steg, tekster og handlinger beholdes. |
| Hjem | 72 pt flate ved hilsenen, uten eget kort. Hilsen høyst én gang per lokal kalenderdag når dagens Hjem faktisk er synlig. Andre datoer bruker stillfigur. |
| Tomme favoritter | Stillfigur over eksisterende tittel/forklaring; «Finn matvarer» beholdes. |
| Tomme lagrede måltider | Stillfigur over eksisterende tittel/forklaring. |

Ingen maskotside, profilinnstilling, snakkeboble, varsling, belønning,
ernæringsstyrt reaksjon, gang-/hvilesløyfe eller maskot i loggkvitteringer.
Ingen backend, migrasjon, synkkontrakt, analyseinnsamling eller nytt kontokrav.
Samme nøytrale positur brukes foreløpig i alle stillillustrasjoner.

## Leveranserekkefølge

1. Bruk de eksisterende flatene og behold tydelig primærhandling.
2. Render transparent V8-stillbilde og integrer de fire plasseringene.
3. Legg til ett bundlet hilseklipp, lokal dagsgrense og stillbildefallback.
4. Kontroller feil, avbrudd, tilgjengelighet, synlig rendering og fysisk enhet.
5. Aktiver animasjon bare etter synlig fysisk avspilling; bruk ellers statisk
   reservevariant. Oppdater gjeldende status og beslutningslogg.

## Berørte komponenter og ansvarsdeling

- `OnboardingIllustration.swift`: eksisterende tosiders førstegangsintro.
  `MatLoggOnboardingFlowView.swift` er en annen flyt og endres ikke.
- `HomeView.swift`: hilsen ved `overviewHeader`; eksplisitt synlighetsverdi fra
  navigasjonsflaten sperrer Hjem-hilsen under onboarding og andre overlegg.
- `ProfileFavoritesView.swift` og `SavedMealsView.swift`: tomtilstander.
- `SporIllustration.swift`: rent stillbilde, SwiftUI-visning og UIKit-adapter.
  Dekorasjonen skjules for VoiceOver og Hjem skjuler figuren ved stor tekst.
- `SporCompanionViewModel.swift`: lasting, avspillingsstate, request-ID,
  avbrudd og avgrenset varighet. Den leser ikke ernærings-/profildata.
- `SporGreetingPolicy.swift`: ren kalenderregel og lite preferansegrensesnitt.
  Siste faktisk startede Hjem-hilsen lagres per installasjon i UserDefaults,
  separat fra domenedata og synkkø. Klokke tilbake utløser ikke ny hilsen.
- `MascotAssets.swift`: ressursgrensesnitt. Bare hilsen og ferdig stillbilde
  inkluderes i vanlig app, ikke Blender-kilder eller øvrige QA-klipp.
- `RealityKitMascotController.swift`: avgrenset rendering og avspilling.
  Rendereren opprettes først etter gyldig modelllasting, ikke av inaktive
  visninger, bakgrunnsfargeoppdateringer eller tom resume/restart.
- `MatLoggApp.swift`: sammensetning ved app-roten. Avslått
  `sporMascotAnimationEnabled` gir ingen avspillingsfactory og ren stillfigur.

Views utfører ingen datatilgang. Ingen featurelogikk legges i `AppState`.
IO- og rendergrenser er injiserbare. Eksisterende transaksjoner, dataeierskap
og `DomainUploadPolicy.localOnly` endres ikke. Ingen arkitekturavvik er kjent
ved kontroll mot `docs/architecture-principles.md`.

## Tilstander og tilgjengelighet

- Reduser bevegelse gir stillfigur uten automatisk avspilling.
- Ressursfeil gir stillbilde uten modal feil eller blokkering av logging.
- Request-ID og kansellering hindrer sen lasting fra å starte på feil flate.
- Inaktiv app og navigasjon bort pauser/fjerner renderflaten.
- Hjem-hilsen krever dagens dato og valgt/synlig Hjem. Onboarding og åpnet
  loggførings-/kameraflyt sperrer den. Retur samme dag gjentar ikke hilsenen.
- Tekst og knapper formidler all nødvendig informasjon uten maskoten.
- Eksisterende design-tokens, tilgjengelighetsidentifikatorer og bunnmenyklaring
  beholdes. Ingen ekstra onboarding-side eller ventetid introduseres.

## Fysisk renderfeil og retting

Første fysiske kontroll viste stillbilder og korrekte navigasjonsflyter, men
figuren forsvant under integrert avspilling. Datoen ble lagret og klippet
spilte teknisk. Både direkte RealityKit-snapshot og skjermbilde var tomme.
Viewport, kamera og modellens plassering var gyldige. Den separate maskotprøven
viste samme modell korrekt på samme iPhone. Animasjonen ble midlertidig slått av.

En minimal visning med den samme integrasjonskomponenten viste korrekt vinking.
Integrasjonen opprettet ARView allerede i controller-init, også for inaktive
og forhåndslastede sider. Utsatt rendereroppretting etter gyldig ressurslasting
gjenopprettet synlig vinking i den faktiske onboarding-flyten. Detaljen i
RealityKits interne håndtering er ikke fastslått; dette er den verifiserte
utløsende forskjellen. Animasjonsflagget er aktivert igjen etter fysisk kontroll.

Endring av viewport-størrelse, tidligere montering av host og gjentatt
animasjonsressurs løste ikke feilen og er ikke beholdt.

## Verifisering og ferdigvurdering

Miljø: fysisk iPhone 17, separat appidentitet
`com.nithusan.MatLogg.spor-integration-qa`, navn «Spor Maskot Apptest».
Vanlig Spor Mat og brukerens matlogger ble ikke endret. QA-prosjektet har
separat signering og tomme entitlements; innlogging og Apple Helse testes ikke.
Appkoden samsvarer med arbeidskopien når midlertidig diagnostikk er fjernet.

Utført:

- Ti målrettede enhetstester bestod på fysisk enhet: kalender/dagsgrense,
  klokke tilbake, lagring etter gjenskaping, separat introgrense, ressursfeil,
  avbrutt lasting og renderer som ikke opprettes for inaktiv/ugyldig presentasjon.
- Fire UI-kontroller bestod: synlig maskot i intro, intro/Hjem/tomme favoritter
  og lagrede måltider, største tekst samt mørk modus/datonavigasjon/bakgrunn.
- En femte UI-kontroll bekreftet vinking på Hjem og overgang tilbake til
  stillbilde. Dagsgrensen ble åpnet med prosesslokal argumentoverstyring i QA,
  uten å slette noen appdata. Denne kjøringen tester ikke gjentatt dagshilsen.
- Vinkingen er visuelt bekreftet i faktisk onboarding og på Hjem. Regresjonskontrollen
  måler synlige maskotpiksler i illustrasjonsområdet, ikke bare navigasjon.
  Den opprinnelige feilens skjermbilde hadde 0 treff mot testens fargemaske.
- `SporCompanionRenderingUITests` krever eksplisitt isolert QA-appidentitet i
  testmiljøet og hopper ellers over, slik at vanlig appdata ikke berøres.
- Reduser bevegelse var først aktivert på enheten og viste korrekt stillbilde.
  Brukeren slo innstillingen midlertidig av for animasjonskontrollen.
- Tidligere Debug-/Release-bundlekontroll viste bare hilseklippet som
  maskotmodell; ingen QA-mappe, Blender-kilder eller gang-/hvileklipp.
- Diffkontroll brukes før commit. Generelle backend-/lagringstester kjøres
  ikke på nytt for denne avgrensede presentasjonsendringen.

Rå resultater og bilder beholdes utenfor repoet, blant annet
`/tmp/spor-greeting-final-device.xcresult` og
`/tmp/spor-lazy-renderer-captures/`. Midlertidig diagnostikk og hindring av
auto-lås er fjernet fra siste QA-kandidat. Kandidaten er bygget fra en
arbeidskopi med annet pågående arbeid; commit avgrenses til maskotfilene.

Manuell VoiceOver-lytting og målt energibruk er ikke utført. Release-bygg av
rettelsen er kontrollert i den utvidede QA-runden nedenfor. Produksjonsutrulling
krever fortsatt relevante releasekontroller og separat go/no-go.

Skills brukt: product-review og product-design ved plan/design,
ios-swiftui og qa-release ved implementering og fysisk kontroll.

## Utvidet QA – 25. november 2026

Ingen nye appfeil ble funnet og ingen produksjonskode ble endret i denne runden.
Nye regresjonstester er lagt til i repoet; rå bilder og logger ligger i `/tmp`.

- 22 ulike enhetstester ble kontrollert på fysisk iPhone 17: eksisterende
  dagsgrense/lagring, sene og overlappende svar, stopp under lasting/klargjøring,
  kansellert avspilling, avbrutt intro, neste dag, feilressurs og feil varighet,
  rendererens frakobling/gjenbruk/størrelse samt presentasjonsgating.
- Systeminnstillingen Reduser bevegelse ble testet på den faktiske telefonen.
  I første kjøring var én betinget test hoppet over fordi innstillingen var av.
  Etter at brukeren slo den på, bestod alle tre presentasjonstestene, inkludert
  null ressursoppslag, null rendereroppretting og ingen brukt dagshilsen.
- Seks UI-tester bestod. De sammenligner faktiske bilder under avspilling:
  intro beveger seg i både lys og mørk modus og blir deretter stillestående;
  sidebytte og bakgrunn stopper introen; Hjem beveger seg ved første start og
  forblir stille etter omstart, fanebytte og bakgrunn samme dag. I tillegg
  består den opprinnelige kontrollen av at figuren ikke blir usynlig.
- 15 av logikktestene bestod også separat på Mac med falske IO-grenser.
- Usignert Release-bygg bestod. Bundlekontroll viste bare hilseklippet,
  ingen QA-mappe, Blender-kilder, testbundler eller Debug-maskotstartargument.
  `DomainUploadPolicy.localOnly` og avslått backend-synk er bevart.
- Testene kompilerer for fysisk iOS. QA-appidentitet og tomme entitlements er
  separate; vanlig Spor Mat og ekte matlogger ble ikke endret.

Resultater: `/tmp/spor-extended-device-ready.xcresult`,
`/tmp/spor-extended-reduced-motion.xcresult` og
`/tmp/spor-release-extended.log`. Telefonens Reduser bevegelse stod på ved slutt.
Disse kontrollene erstatter ikke manuell VoiceOver-lytting eller energimåling.

## Trykkhilsen – 25. november 2026

Ny avgrensning: på dagens Hjem er Spor en navngitt knapp med minst 44 pt
trykkflate (faktisk 72 pt). Trykk spiller én hilsen; ekstra trykk under lasting
eller avspilling ignoreres. Manuell hilsen har ingen dagsgrense og endrer ikke
lagret dato for automatisk hilsen. Andre flater/datoer beholdes som før.

Reduser bevegelse slår av automatiske hilsener, men et bevisst trykk på
«La Spor vinke» kan spille animasjonen. VoiceOver får navn, hint og status.
Ved stor tekst legges knappen på egen rad. Navigasjon/bakgrunn stopper den.
Manuell oppgave, busy-state, avbrudd og dato-policy eies av ViewModel;
renderer/repository og domenelagring er uendret. Ingen arkitekturavvik.

Kontrollstatus for trykkhilsen:

- 22 isolerte logikktester bestod på Mac, inkludert sju nye tester av manuell
  dagsgrense, raske trykk, busy-state, feil og avbrutt lasting.
- På iPhone bestod 28 enhetstester; den eksisterende systemavhengige testen
  av Reduser bevegelse ble hoppet over fordi innstillingen var av.
- To UI-kontroller bestod for trykk, gjentatt avspilling, ignorering av ekstra
  trykk, stopp etter bakgrunn og største tekststørrelse. To regresjonskontroller
  av automatisk bevegelse og dagsgrense etter omstart bestod også.
- Release-bygg bestod. Den siste knappestiljusteringen er etter dette
  kompilert i QA-bygget; ingen produksjonsutrulling er utført.
- Visuell kontroll fant at vanlig deaktivert knappestil dempet maskotfargene
  under avspilling. En egen ren knappestil bevarer artwork uten slik demping.
  En fargeregresjonsassert er lagt til; siste fysiske kontroll av denne
  justeringen er ikke kjørt.
- Brukeren ba om å utsette de resterende fysiske kontrollene til før PR mot
  main. Gjenstår: trykkhilsen med systemets Reduser bevegelse på, og siste
  visuelle/fargemessige kontroll av normal/stor tekst. Tidligere manuell
  VoiceOver-/energikontroll er fortsatt ikke utført.

Rå resultater ligger utenfor repoet, blant annet
`/tmp/spor-tap-device-paired.xcresult`,
`/tmp/spor-tap-automatic-regression.xcresult` og `/tmp/spor-tap-first-captures/`.
Ingen nye appressurser eller rå QA-filer er lagt til i repoet.
