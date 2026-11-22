# Spor-maskot – isolert iOS-prøve

Intern Debug-QA, implementert 22. november 2026. Ingen plassering i den vanlige
appen eller produksjonsutrulling er valgt. Simulatoren er tidligere kontrollert;
fysisk vurdering av den siste hilsenen gjenstår.

## Starte prøven

I Xcode: velg det delte schemet **Spor Maskot QA**, velg iPhone eller
simulator som destinasjon, og trykk ▶️ (⌘R). Det åpner maskoten direkte.
Schemet bruker `Debug-SporMascotQA`, `Config/SporMascotQA.xcconfig` og
startargumentet `--spor-mascot-qa`. Appen heter «Spor Maskot QA» og har
separat appidentitet `com.nithusan.MatLogg.mascotqa`. QA-konfigurasjonen
bruker en tom entitlement-fil siden prøven ikke bruker HealthKit eller
Apple-innlogging. Det vanlige MatLogg-schemet er uendret. QA-schemet har
ingen Profile-/Archive-handling.
Dette velger QA-roten før `DemoAppRoot`/`MatLoggContent` initialiseres.
QA-roten bruker ingen database, konto, HealthKit eller nettverk.

```sh
xcodebuild test -project MatLogg.xcodeproj -scheme "Spor Maskot QA" \
  -destination 'platform=iOS Simulator,id=<QA-simulator-ID>' \
  -derivedDataPath /tmp/MatLoggMascotQA \
  -only-testing:MatLoggTests/SporMascotPreviewTests \
  -only-testing:MatLoggUITests/SporMascotPreviewUITests \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO
```

Etter simulator-testen kan den installerte QA-appen åpnes direkte:

```sh
xcrun simctl launch <QA-simulator-ID> com.nithusan.MatLogg.mascotqa --spor-mascot-qa
```

Skjermen har Hvile/Hilsen/Gange, spill/pause/omstart, tre størrelser og
system/lys/mørk visning. Redusert bevegelse starter med en stillestående
figur; eksplisitt avspilling er mulig. Inaktiv app pauser og kobler renderflaten
fra visningen. Manuell pause bevares ved retur. Hurtige klippbytter beskyttes
med forespørsels-ID i både ViewModel og loader.

Testargumentene `--spor-mascot-missing-asset` og
`--spor-mascot-reduced-motion` gir deterministiske QA-tilstander. De finnes
bare sammen med den særskilte QA-koden.

## Ressurser og eksport

`qa-assets/spor/` inneholder bare de tre valgte USDZ-filene, et lite manifest
og et reservebilde. Hvile/gange har 18 978 trekanter, hilsen har 19 698;
de tre USDZ-filene er samlet 1 753 756 bytes. Originalen er
`docs/assets/brand/3d/spor-mascot-v8.blend`. Eksporter fra denne med
`scripts/export-spor-mobile.py`, én prosess om gangen:

```sh
mkdir -p /tmp/spor-usdz-tmp
TMPDIR=/tmp/spor-usdz-tmp /Applications/Blender.app/Contents/MacOS/Blender \
  --background docs/assets/brand/3d/spor-mascot-v8.blend --python-exit-code 1 \
  --python scripts/export-spor-mobile.py -- --output-dir qa-assets/spor --clip idle
```

Gjenta med `greeting` og `walk`. `--ascii --output-dir /tmp/spor-export`
gir en lesbar USD-kandidat for feilsøking uten store tekstfiler i repoet.

Eksportkopien forenkler kroppen, fjerner Subdivision/Corrective Smooth og
bruker matt PBR-farge uten prosedyrekorn. Bevegelse og ansiktsdrivere samples
til USD; runtime kjører ikke Blender-drivere. Den svært lille animerte
beinskaleringen bevares ikke av installert eksportør. Eksportkopien bruker
derfor en tilsvarende liten vertikal kroppsbevegelse som pust i hvile/hilsen.
Gange eksporteres uten fremdrift i Root, slik at figuren blir i modellområdet.

Hilsenen har en egen rund mobilarm med full vekt til skulderleddet. Den
sammenhengende modellens blandede kropp-/armvekter klemte hånda flat ved
løft i RealityKit (reprodusert i iPhone-opptak). Eksportkopien gjenoppretter
kroppsflaten under armen og lar den runde armen overlappe ved skulderen.
Armen løftes tydelig og gjør to små vink; klippet er fortsatt seks sekunder.
Dette gjelder bare hilsenen. Hvile, gange og V8-kildefilen er uendret.
Kontroll av kantlengder gjennom hele klippet viste maksimalt 0,5 % endring
fra pustebevegelsen; hånda klemmes ikke lenger av blandede vekter.

Dette er en mobilkandidat: overflate, skygger og skulder-/ankeldeformasjoner
avviker noe fra Blender-renderen. Kildemodellen endres ikke av eksporten.

## Isolasjon og arkitektur

Koden er avgrenset med `DEBUG && SPOR_MASCOT_QA`. Ressurskopieringen krever
både Debug/Debug-SporMascotQA, `SPOR_MASCOT_QA=YES` og den samsvarende
kompileringsbetingelsen.
Vanlige bygg fjerner eventuell gammel QA-ressursmappe fra eget byggprodukt.
Blender-/GIF-filer er utenfor appens synkroniserte mappe og pakkes ikke.
Byggesteget deklarerer både QA-mappen og hver av de fem utdatafilene:
Xcodes sandbox gir bare tilgang til selve stien når en mappe deklareres.
Pakkingstesten kjører også kopiering, overskriving og opprydding under
slike sandbox-regler, med kanonisk `/private/tmp`-sti. Testen reproduserte
`manifest.json: Operation not permitted` før fillisten ble rettet og bestod
etterpå. Tidligere bygg under `/tmp` fanget ikke denne begrensningen.
Nytt iPhone-bygg i den samme DerivedData-mappen som Xcode-feilen bestod
med sandbox aktivert; alle fem ressurser ble kontrollert i appen.

ViewModel eier feature-state og bruker et injisert repository og avspillings-
grensesnitt. Repositoryet skjuler filoppslag; RealityKit-controlleren eier
scene, lasting og avspilling. QA-roten setter sammen avhengighetene. Ingen
IO i SwiftUI-`body`, endring av `AppState`, domenelagring eller synkpolicy.

## Verifisering og gjenstående arbeid

Funksjonell QA på «Spor Mat Health Release QA», iOS 18.6, Xcode 27.2:
seks Swift Testing-tester og fire UI-tester. Dekker feil/retry, gamle og
kansellerte lasteresultater, manuell pause/bakgrunn, redusert bevegelse,
tre klipp og stor tekst/utseende. Simulatorbildene og `.xcresult` beholdes
under `/tmp/MatLoggMascotQA` og `/tmp/spor-screenshots-verified`, utenfor repoet.
De seks unit-testene og fire UI-testene bestod; alle fire UI-testene bestod
også etter siste visuelle layoutrettelse. Siste UI-resultat er
`Test-MatLogg-2026.11.22_12-55-20-+0100.xcresult` under DerivedDatas `Logs/Test/`.
Hilsenen ble i tillegg kontrollert med løftet arm i et felles kamerautsnitt
med plass til hele figuren; den berørte testen bestod etter kamerajusteringen
(`Test-MatLogg-2026.11.22_13-02-20-+0100.xcresult`).
Vanlig Release uten QA-xcconfig bestod; den genererte appen inneholder verken
QA-ressursmappe, maskot-USDZ-filer eller QA-inngangens binærkjennetegn.
`bash scripts/verify-spor-qa-packaging.sh` kontrollerer også vanlig Debug,
Release med QA-variabel satt og manglende kompileringsbetingelse.

Det delte QA-schemet er bygget for `generic/platform=iOS` med eksisterende
utviklingssignering. Bygget bestod; appidentitet, alle fem QA-ressurser og
kodesignatur er kontrollert. Schemet starter med maskotargumentet aktivert.
Vanlige Debug-/Release-konfigurasjoner er bevart, og pakkingstesten bestod
også med `Debug-SporMascotQA`. Etter håndrettelsen bestod iPhone-bygget
på nytt, og den oppdaterte QA-appen ble installert på den tilkoblede iPhonen.

Den oppdaterte hilsenen er i tillegg lastet i RealityKit på macOS og
kontrollert ved 0, 1, 1,8, 2,5, 3,5, 4,5 og 5,99 sekunder med appens
kameravinkel. Varigheten er seks sekunder, og hele hånda er synlig.
Bilder og kontrollskript ligger i `/tmp/spor-recording-review`, utenfor
repoet. iOS 18.6-runtime er ikke lenger installert, så den siste
ressursendringen er ikke kontrollert i iOS-simulator.

Innlasting og eksportert blunk er tidligere observert i RealityKit i simulatoren.
Deployment target er fortsatt iOS 17, men ingen iOS 17-runtime er installert:
visuell animasjonskompatibilitet der er ikke verifisert. Visuell vurdering av
siste hilsen på iPhone, VoiceOver med faktisk opplesning, kaldstart/FPS/minne
og lengre avspilling
er fortsatt åpne. Ingen ytelsesmål eller produksjonsklarhet er godkjent.

Skills: product-review, product-design, ios-swiftui, qa-release.
Se [implementeringsplanen](plans/spor-mascot-iphone-preview.md) for porter og
senere beslutninger om bruk i produktet.
