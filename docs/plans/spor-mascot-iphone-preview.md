# Implementeringsplan – Spor på iPhone

Dato: 22. november 2026. Status: Debug-prøve implementert; funksjonell simulator-QA,
siste layoutjustering og Release-isolasjon verifisert.
Brukeren valgte simulator først og fysisk iPhone senere. iOS 17-visning og
fysisk ytelses-/tilgjengelighetskontroll er fortsatt åpne. Se
[kjøreveiledning og faktisk status](../spor-mascot-preview.md).

## Mål og scope

Lage en isolert testskjerm på fysisk iPhone for å vurdere V8-maskotens uttrykk,
animasjoner, lesbarhet og ressursbruk i faktisk appstørrelse. Dette er intern
design-/teknisk QA, ikke en ny MVP-funksjon eller et valg om hvor maskoten skal
brukes i produktet. Første leveranse er sanntids-3D med Hvile, Hilsen og Gange,
valg av størrelse og lys/mørk bakgrunn, samt spill/pause og omstart.

Forutsetning: den foreløpig valgte 2D-maskoten og V8 er referansene.
Ingen ny figurdesign, AR, kamera, lyd, samtalefunksjon, belønninger, kobling til
mat/vekt/mål eller produksjonsutrulling inngår. Ingen brukerdata skal leses
eller lagres. Testen fungerer helt offline.

## Bekreftet utgangspunkt

- [V8](../assets/brand/3d/spor-mascot-v8.blend) har tre actions, ti bein,
  ansikts-shape keys styrt av drivere og Corrective Smooth/Subdivision.
  Modellen og GIF-ene er Blender-prototyper; ingen mobilmodell er eksportert.
- Prosjektets deployment target er iOS 17.0. Planen øker ikke dette kravet.
- Appens faktiske `@main` ligger i `MatLogg/App/DemoAppRoot.swift`.
  Den velger allerede egne Debug-røtter før `DemoAppRoot` initialiseres.
- `MatLoggContent` setter sammen database, auth og øvrige tjenester. Den skal
  ikke initialiseres når maskot-testen startes.
- Appen bruker filsystemsynkroniserte Xcode-grupper. QA-ressurser må derfor
  plasseres og pakkes bevisst, slik at de ikke automatisk følger vanlig app.
- Mange eksisterende arbeidsfiler er endret. Implementeringen skal bevare
  disse, også ved den lille endringen i app-roten og Xcode-prosjektet.

## Anbefalt teknisk retning

SwiftUI for kontrollene og RealityKit med `ARView` i `.nonAR`-modus, pakket i
en liten `UIViewRepresentable`. Dette gir en kandidat som kan prøves på
prosjektets iOS 17-grunnlag, uten kamera eller AR-tillatelser. Bruk USDZ til
bundlet modellinnhold. Eksakt støtte for eksporterte ansiktsanimasjoner på
minimumssystemet er en kontrollport, ikke en antakelse.

Første versjon bruker én USDZ-fil per animasjon, med samme koordinatsystem,
skala, hvilepositur og kamerautsnitt. Det gjør klippene enklere å kontrollere
hver for seg. Bare én scene og én aktiv avspillingskontroller lever om gangen.
Ikke gjenbruk GIF-ene som selve 3D-testen; de er visuelle sammenligningsbilder.

## 1. Eksporttest før skjermbygging

**Leveranse:** én Hvile-kandidat som faktisk laster og beveger seg i RealityKit.

1. Lag en separat eksportkopi av V8; bevar originalfilen og riggen.
2. Eksporter bare maskot, nødvendig skjelett og ansikt. Utelat skjult
   `KILDE`-samling, gamle actions, Blender-kamera, gulv og studiolys.
3. Sample/bake beinanimasjon og ansiktsverdier. Drivernes uttrykk skal ikke
   være en runtime-avhengighet. Kontroller Corrective Smooth og Subdivision
   særskilt: de må få en støttet representasjon eller erstattes i eksportkopien.
   Ingen ukontrollert full vertex-cache som snarvei til mobilavspilling.
4. Start med matt PBR-materiale og enkel farge. Bake eventuell korn-/normaltekstur
   til en liten tekstur hvis det gir synlig verdi. Prosedyrenoder er ikke
   forutsatt å følge eksporten.
5. Kontroller Y-opp, meter, normaler, material-/skjelettbindinger og at
   eksporten ikke får utilsiktet ekstra subdivision.
6. Last filen i en minimal RealityKit-test på simulator og fysisk telefon.
   Sammenlign normalpose, blunk, blikk og skuldre med Blender-referansen.
   Prøv også på iOS 17 dersom støtten der fortsatt skal påstås.

**Port A:** Ikke bygg hele kontrollskjermen før ett klipp fungerer gjennom
hele kjeden Blender → USDZ → RealityKit. Hvis ansikts-/deformasjonsstøtten
svikter, prøv en enklere skjelettbasert eksportkopi. Dokumenter tap av uttrykk.
Hvis det fortsatt krever større rigg-/modellarbeid, synliggjør konsekvensen
før videre scope velges. En video- eller GIF-visning kan vurderes separat som
visuell prøve, men fullfører ikke denne sanntids-3D-planen.

## 2. Lage en mobilkandidat av alle klipp

**Leveranse:** Hvile, Hilsen og Gange, pluss et statisk reservebilde og et
lite manifest med klipp-ID, ressursnavn og forventet varighet.

- Bevar ansikt og silhuett ved forenkling. Mål antall synlige trekanter,
  teksturstørrelser og total ressursstørrelse; `.blend`-filstørrelsen sier
  ikke hvor kostbar modellen er på telefonen.
- Foreslått startbudsjett, som må vurderes etter første måling: høyst 20 000
  synlige trekanter, teksturer opptil 1024 px og opptil 10 MB samlet for de
  tre modellfilene. Dette er arbeidsmål, ikke dokumentert ytelse.
- Bake Gange som en syklus uten fremdrift i Root, slik at han holder seg
  innenfor testområdet. Bevar fotbevegelsene relativt til kroppen. Kamera og
  lys styres av appen og skal ikke følge med Root fra Blender.
- Kontroller klippenes start/slutt, pausetilstand, omstart og overgangen
  mellom klipp. Deling av modellgeometri mellom klipp er senere optimalisering
  dersom duplisert innhold blir et problem.
- Legg bare den valgte QA-kandidaten i `qa-assets/spor/`. Rå eksporter,
  gjentatte målinger, skjermopptak og store rapporter beholdes utenfor repoet.

## 3. Isolert QA-inngang og arkitektur

**Leveranse:** en Debug-test som kan startes uten normal app-initialisering.

- Ny `SporMascotQARoot` velges i `DemoAppRoot.swift` før `DemoAppRoot()` ved
  et eksplisitt launch-argument `--spor-mascot-qa`.
- Kompiler inngangen og QA-koden bare med `DEBUG && SPOR_MASCOT_QA`.
  Bruk en egen lokal QA-xcconfig som både setter kompileringsbetingelsen og
  et byggevalg for ressurskopieringen. Kopier modellene inn bare i disse
  QA-byggene. Ressursene legges utenfor den vanlige appens synkroniserte mappe.
- Bruk separat QA-appidentitet på fysisk iPhone, slik at installasjonen ikke
  erstatter vanlig app eller bruker dens datacontainer/nøkkelring.
- Ingen database, konto, HealthKit, nettverkskall eller synk opprettes av denne
  roten. Testvalgene er midlertidig minnestate.

Ansvarsdeling:

| Del | Ansvar |
| --- | --- |
| `SporMascotPreviewView` | Presentasjon og videresending av brukerhandlinger. |
| `SporMascotPreviewViewModel` | Lastetilstand, valgt klipp/størrelse/utseende, spill/pause, feil og håndtering av raske klippbytter. |
| `MascotAssetRepository` | Manifest, klippmetadata og oppslag av bundlet ressurs, bak et lite injisert grensesnitt. |
| RealityKit-controller/loader | Asynkron sceneinnlasting, RealityKit-objekter, kamera/lys, avspilling og frigjøring. ViewModel bruker et protokollgrensesnitt uten RealityKit-typer. |
| `MascotSceneView` | SwiftUI-/UIKit-adapter som viser controllerens scene. Ingen ressursinnlasting i `body`. |
| `SporMascotQARoot` | Setter sammen avhengighetene og livssyklusen. |

ViewModel er `@MainActor`. IO gjøres asynkront; RealityKit-oppdateringer følger
rammeverkets actor-krav. Bruk avbrudd eller forespørsels-ID slik at et gammelt
lasteresultat ikke erstatter siste klippvalg. Hold én scene aktiv, stopp
forrige klipp ved bytte og unngå å rekonstruere scenen for hvert UI-tastetrykk.
`AppState`, domene-repositories, synkkontrakt og local-only-policy endres ikke.

Foreslåtte nye kodefiler følger ansvarsdelingen under `App/`, `Views/`,
`ViewModels/` og `Services/Mascot/`. Bruk små protokoller ved innlastings- og
avspillingsgrensen. Ingen generell maskotplattform eller nytt UI-rammeverk.

## 4. Skjerm og interaksjoner

**Leveranse:** én fullskjerms QA-visning uten vedvarende bunnmeny.

Rekkefølge: tittel «Spor – forhåndsvisning» → modellområde → animasjonsvalg
«Hvile / Hilsen / Gange» → «Spill av / Pause» og «Start på nytt» → størrelse
«Liten / Middels / Stor» → utseende «System / Lys / Mørk».

Start med modellområder på omtrent 96, 180 og 280 pt, begrenset av tilgjengelig
bredde/høyde. Bruk samme kameravinkel og proporsjoner ved alle størrelser.
Kontrollene kan rulle ved stor tekst eller liten skjerm. Gjenbruk `AppColors`,
`AppTypography` og eksisterende knappeflater; ingen nye fargetokens er nødvendig.
Denne separate QA-roten ligger ikke under bunnmenyen. Eventuell senere
innføring i en fane må bruke `matLoggTabBarScrollClearance()`.

Tilstander og adferd:

- Laster: «Laster Spor …», med utilgjengelig avspilling frem til modellen er klar.
- Klar: Hvile er forhåndsvalgt. Spill/pause-status vises med tekst og ikon.
- Feil/manglende ressurs: «Kunne ikke laste Spor», statisk reservebilde og
  «Prøv igjen». Ingen krasj eller uendelig spinner.
- Bakgrunn/inaktiv scene: stopp avspilling og løpende rendering. Ved retur
  gjenopprettes forrige tilstand; et manuelt pauset klipp starter ikke av seg selv.
- Redusert bevegelse: vis en stillestående positur som standard; eksplisitt
  «Spill av» kan brukes for en kontrollert prøve. Ingen automatisk restart.
- VoiceOver leser valgte kontroller og spillestatus. Selve figuren er dekorativ
  i denne kontrollskjermen; den må ikke gi løpende animasjonsannonseringer.
  Dynamic Type og minst 44 pt trykkflater inngår i skjermen.

## 5. Målrettet verifisering

**Automatisk:** unit-tester med falsk loader/player for lasting, feil, retry,
raske klippbytter, pause/omstart, bakgrunn og redusert bevegelse. En liten
UI-suite for QA-inngang, tre klippvalg, størrelse/utseende og feiltilstand.
Feilressurs testes gjennom injisert fixture. Test også at vanlig oppstart
fortsatt velger eksisterende rot, og at Release ikke eksponerer QA-inngangen
eller pakker QA-modellene. Bruk prosjektets målrettede `xcodebuild test`-mønster
fra `docs/testing.md`, dedikert simulator og egen DerivedData.

**Fysisk iPhone:** mål kald sceneinnlasting, jevn avspilling, minne etter
20 klippbytter, tre minutter med avspilling og retur fra bakgrunnen. Sammenlign
alle tre størrelser, lys/mørk, stor tekst, VoiceOver og redusert bevegelse.
Kontroller særlig blunk/blikk, skuldre og fotkontakt fra Blender-referansen.

Foreslåtte første ytelsesmål: klar til visning innen 1 sekund etter kald
sceneinnlasting, minst stabil 30 fps under avspilling, og ingen vedvarende
minnevekst etter oppvarming/klippbytter. Loggfør målemetode, enhet, OS og
avvik. Tallene er foreløpige akseptansemål; de er ikke målt i dette arbeidet.
En nyere telefon alene dokumenterer ikke ytelse på alle støttede enheter.

## Ferdigdefinisjon og beslutningsporter

- **A – Eksport:** ett klipp laster korrekt i målrendrer på iPhone.
- **B – Komplett prøve:** tre klipp kan velges, pauseres og startes på nytt;
  størrelser og tema fungerer offline, med kontrollert feiltilstand.
- **C – Vurdering:** fysisk måling og visuell kontroll er dokumentert. Eventuelle
  avvik fra iOS 17-støtte eller ytelsesmål er synlige før konklusjon.
- **D – QA-isolasjon:** separat appidentitet og Debug-ressurser er bekreftet,
  ingen normal datainitialisering og ingen maskotressurser i vanlig Release.

Anbefalingen etter C er én av: videreføre sanntids-3D, optimalisere kandidaten
eller vurdere en rendret løsning. Fast plassering i appen og eventuell
distribusjon er egne senere beslutninger. Oppdater designsystem/status ved
implementering; før et varig format-/scopevalg i `docs/decisions.md` når det
faktisk er verifisert og valgt. Denne planen innfører ingen arkitekturavvik.

## Kilder og status

Skills: product-review, product-design, ios-swiftui og qa-release.
Planen ble kontrollert mot prosjektets arkitektur, app-rot, deployment target
og V8-generator før implementering. Faktisk implementering, eksporttilpasninger,
testresultater og åpne enhetskontroller føres i kjøreveiledningen lenket øverst.

- [Apple: Creating USD files for Apple devices](https://developer.apple.com/documentation/usd/creating-usd-files-for-apple-devices)
  – målrenderer, koordinater, validering og innholdsoptimalisering.
- [Apple: ARView.CameraMode.nonAR](https://developer.apple.com/documentation/realitykit/arview/cameramode-swift.enum/nonar)
  – 3D-visning uten plassering i den virkelige verden.
- [Blender: USD export](https://docs.blender.org/manual/en/5.0/files/import_export/usd.html)
  – skjelett- og shape-key-eksport som må kontrolleres mot installert Blender
  og valgt iOS-versjon.
