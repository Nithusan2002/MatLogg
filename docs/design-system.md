# MatLogg – designsystem

MatLogg bruker et varmt, rolig og kortbasert designsystem som skal gjøre
matlogging rask og næringsinformasjon forståelig uten å virke dømmende.

Swift-koden under `MatLogg/DesignSystem/` er teknisk sannhetskilde for konkrete
verdier. Dette dokumentet er normativt for betydning, bruk og innføring av nye
tokens og komponenter.

## Prinsipper

1. Bruk visuell struktur for å gjøre logging raskere, ikke for dekor alene.
2. Bruk semantiske tokens fremfor farge-, font- og radiusverdier i featurekode.
3. La typografi og spacing etablere hierarki før flere kort introduseres.
4. Bruk farge som signal sammen med tekst eller ikon, aldri som eneste bærer.
5. Skill datakilde, dokumenterte verdier og brukeroppgitte verdier tydelig.
6. Design lys modus, mørk modus, Dynamic Type, VoiceOver og økt kontrast
   samtidig.
7. Ernæringsstatus, mål og vekt skal presenteres nøytralt. Kalorier og
   tilgjengelige makroverdier skal være konsistente i synlig UI og
   tilgjengelighetstre.

## Farger

Oppstartsvisningen viser logoen med transparent bakgrunn uten kort eller ramme,
med «MatLogg» i stor, Dynamic Type-skalert tekst under og en liten spinner.
I mørk modus vises logoen som en lys silhuett med `ink` for tydelig kontrast.
Den bruker `background`, `ink` og `action`, og VoiceOver annonserer
«Åpner MatLogg». Visningen varer bare mens lokal kontekst klargjøres;
ingen kunstig forsinkelse eller ekstra animasjon legges til.

Fargene defineres semantisk i `MatLogg/DesignSystem/Colors.swift`.

Sekundærtekst bruker `#70656D` i lys modus for minst 4,5:1 kontrast på
`background`, `surface`, `warmSurface` og `mutedSurface`. `actionText` og
`errorText` deler kontrastsikker farge, men har ulike semantiske roller.
Feilmeldinger bruker `ErrorMessageView` med ikon og tekst; retry-handlinger
beholdes ved meldingen der de finnes.

Energi og informasjon deler blåfamilien `energyTint`/`info`. Fylte energikort
bruker fast mørk `onVibrant` uten opacity i begge moduser. Diagramstolper bruker
`energyChart`, en kontrastsikker blåvariant, og dagens stolpe får synlig
«I dag»-tekst. Mållinjen er stiplet og bruker full `textSecondary`.
Makrofargene er aliaser til `brand`, `accent` og `success`.

Alle valgte måltidschips viser hake i tillegg til farge og valgt-status for
VoiceOver. Kameraets faste svart/hvitt-flater og slør ligger i sentrale
`scanner…`-tokens; lasting bruker `info`. Asset Catalog sin `AccentColor`
bruker samme light/dark-verdier som `action` for arvet tint. Nutri-Score- og
NOVA-fargene beholdes uendret.

Måltidsvalg ved logging og redigering bruker `MealChip` med full kolonnebredde
i et rutenett med to kolonner og 8 pt avstand. Ved tilgjengelighetsstørrelser
for Dynamic Type brukes én kolonne. Begge bruker Frokost, Lunsj, Middag og
Kveldsmat som visningsnavn.


| Token | Formål |
| --- | --- |
| `background` | Sidens grunnflate. |
| `surface` | Kort, skjema og ordinære innholdsflater. |
| `warmSurface` | Varm sekundær fremheving. |
| `energySurface`, `energySurfaceEnd`, `energySurfaceGradient` | Korallsol: diagonal korall–aprikos-gradering for energi- og vannoversikten på Hjem (`#FFB5B9` → `#FFD8AE` i lys modus, `#542C33` → `#443121` i mørk modus). Flaten er lik uansett målstatus; vann beholder blå detaljer. |
| `energyTextSecondary` | Kontrastsikker sekundærtekst på Korallsol (`#594B54` i lys modus, `#C9BDC3` i mørk modus). |
| `mutedSurface` | Diskret status, valgt bakgrunn eller sekundær informasjon. |
| `ink` | Primær tekst og ikoner. |
| `deepInk` | Høyere visuell vekt på overskrifter og sentrale elementer. |
| `textSecondary` | Metadata, forklaringer og sekundær status. |
| `separator` | Skillelinjer og svake kortgrenser. |
| `brand` | Merkevare og enkelte sterke flater. |
| `action` | Kontrastverifiserte handlingslenker og valgt navigasjon. |
| `onVibrant` | Tekst og ikoner på sterke merke-/makrofarger. |
| `controlBorder` | Tydelig ramme for input og kontroller. |
| `success` | Fullført teknisk handling eller bekreftet tilstand. |
| `info` | Informasjon uten positiv eller negativ vurdering. |
| `macroProteinTint`, `macroCarbTint`, `macroFatTint` | Identifiserer makrotyper; ikke verdi eller kvalitet. |

`brand` og `action` har ulike roller og skal ikke byttes om etter smak. Sterke
makrofarger krever `onVibrant` når de brukes bak tekst. Grønt betyr ikke «bra
mat», og rødt skal ikke automatisk bety at brukeren har spist «for mye».

Nye farger skal:

- ha et formålsbasert navn
- fungere i lys og mørk modus
- kontrastkontrolleres i faktisk kombinasjon
- løse et gjentatt behov, ikke bevare en engangsjustering

## Typografi

Typografiske roller defineres i `MatLogg/DesignSystem/Typography.swift`.

| Rolle | Bruk |
| --- | --- |
| `display` | Én kort hero-verdi eller introduksjon. Skal brukes sjelden. |
| `hero` | Kraftig, avrundet hovedutsagn eller stor sidetittel. |
| `heroValue` | Stor næringsverdi med middels vekt, vanlig systemfont og tabellariske sifre. |
| `title` | Skjerm- og hovedkorttitler. |
| `sectionTitle` | Seksjonsoverskrifter. |
| `body` | Brødtekst og ordinære verdier. |
| `bodyEmphasis` | Handlinger, feltnavn og fremhevet brødtekst. |
| `secondary` | Ofte lest sekundærtekst, mengder og næringsverdier (skalerbar subheadline, normalt 15 pt). |
| `secondaryEmphasis` | Fremhevet sekundærtekst og handlinger i måltidskort. |
| `caption` | Kompakt metadata og korte, mindre sentrale etiketter. |
| `captionEmphasis` | Kompakte etiketter og status. |

Typografien følger godkjent prototype 10: kraftige, avrundede hovedoverskrifter,
avrundede titler og seksjonsoverskrifter med halvfet vekt, og vanlig systemfont
i brødtekst, matvarenavn og metadata. Store næringsverdier bruker `heroValue`
med middels vekt og tabellariske sifre. Native tekststiler bevarer Dynamic Type;
prototypens pikselstørrelser kopieres ikke direkte. Lange forklaringer skal
ikke bruke tunge displaystiler. Kritiske krav, kilder og feil
skal kunne bryte over flere linjer og ikke skjules av trunkering.

All tekst skal støtte Dynamic Type. Fast skriftstørrelse krever en begrunnet,
kort visningsrolle og må testes med større tekst.

## Spacing og layout

Bruk en konsekvent rytme basert på eksisterende layoutverdier:

- 4 pt – svært tett intern avstand
- 8 pt – ikon/tekst og relaterte kontroller
- 12 pt – kompakte rader og felter
- 16 pt – standard skjerminnrykk og kortpadding
- 18–20 pt – eksisterende seksjonsrytme der 16 pt blir for tett
- 24 pt – tydelig skille mellom innholdsgrupper
- 32 pt – sjeldent, mellom større regioner

Elementer i samme gruppe står tettere enn separate grupper. Unngå nestede kort
og stablet padding. Nye spacing-tokens bør samles i kode når skalaen brukes på
tvers av flere komponenter; featureviews skal ikke etablere parallelle skalaer.

På Hjem brukes 16 pt mellom innholdsgrupper og 12 pt mellom måltidskortets
overskrift og innhold og mellom matvarer. Tomtekst har innholdsstyrt høyde,
uten ekstra minimumshøyde. Måltidsseksjoner bruker 16 pt padding, lys `surface`-kortflate, 24 pt
kontinuerlige hjørner og designsystemets diskrete skygge uten ytre kant. Produktbilder er 52 pt med 2 pt innvendig luft og hele varen synlig. Tekst og trykkflater komprimeres ikke.
Fylte måltidsseksjoner viser matvarenavn og mengder for opptil tre varer og én
samlet næringsrad for hele måltidet: kcal, protein, karbohydrater og fett.
Totalen inkluderer varer bak «+ flere», summeres før avrunding og kan bryte
over flere linjer. Detaljer per vare vises når måltidet åpnes.

### Klarering for bunnnavigasjon

Alle `ScrollView`, `List` og `Form` som vises inne i appens vedvarende
fanenavigasjon skal bruke `matLoggTabBarScrollClearance()`. Dette gjelder både
hovedfaner og skjermer som pushes i fanenes `NavigationStack`, slik at siste rad
alltid kan rulles helt over den egendefinerte bunnmenyen.

Modifieren skal ikke brukes i sheets, fullskjermsvisninger, innlogging eller
onboarding, fordi bunnmenyen ikke er synlig der. Nye fanebaserte skjermer skal
bruke den delte modifieren fremfor lokale bunnpaddinger. Den delte høyden eies
av `MatLoggTabBar`, måles ved kjøring og inkluderer luft over menyen;
featurekode skal ikke kopiere verdien. Ikke-scrollbare faneskjermer skal på
tilsvarende måte holde bunntilknyttet innhold og handlinger utenfor menyens
område.

## Form og hjørner

Eksisterende mønster er kontinuerlige avrundede rektangler:

- 8–12 pt for små kontroller og kompakte rader
- 14–18 pt for vanlige kort
- større radius bare for tydelige ark, hero-flater eller den sentrale handlingen
- `Capsule` for chips og korte valgalternativer
- `Circle` for den sentrale Loggfør-handlingen og ekte ikonknapper

Større radius skal uttrykke gruppering eller prioritet, ikke tilfeldig variasjon.

## Høyde og trykkflater

- alle handlinger skal ha minst 44 × 44 pt effektiv trykkflate
- primærknappen er normalt 56 pt høy
- små ikoner kan være visuelt mindre dersom treffområdet fortsatt er 44 pt
- felt og chips skal tåle større tekst uten å miste etikett eller valgt tilstand

## Komponenter

Gjenbruk eksisterende komponenter før nye varianter bygges:

| Komponent | Ansvar |
| --- | --- |
| `CardContainer` | Ordinær innholdsgruppe med surface, radius og diskret grense. |
| `PrimaryButton` | Én tydelig primærhandling i en skjermregion. |
| `MealChip` | Valg av måltid med eksplisitt valgt tilstand. |
| `AmountInputRow` | Mengde, numerisk input og enhet samlet. |
| `SummaryPill` | Kort oppsummering av én navngitt verdi. |
| `ProgressRow` | Nøytral visning av verdi mot et valgfritt mål. |
| `ProductHeroImageView` | Produktbilde med stabil placeholder og ramme. |
| `ProductThumbnailView` | Kompakt produktbilde i lister, med stabil størrelse og nøytral placeholder. |

En ny delt komponent skal løse et gjentatt interaksjons- eller stilbehov. Små,
rent lokale views trenger ikke flyttes til designsystemet.

### Knapper

Begrens hver skjermregion til én åpenbar primærhandling. Sekundære handlinger
bruker tekst, systemkontroll, diskret grense eller svak flate. Destruktive
handlinger bruker systemets destructive-rolle og en tydelig bekreftelse når
konsekvensen er vesentlig.

### Kort

Kort brukes når innhold trenger en reell grense, for eksempel dagsstatus,
måltidsoppsummering eller personvernvalg. Ikke legg hvert tekstavsnitt i et kort,
og unngå kort inni kort.

Dagsstatus på Hjem følger en tidsstyrt hilsen for i dag («Dagsoversikt» for andre datoer) og bruker én samlet
`warmSurface`-flate med 24 pt hjørner og 20 pt padding. Registrert energi
bruker skalerbar `heroValue`-typografi; balansen mot målet vises nøytralt under.
Makroer vises i tre kolonner med verdi og sekundært mål, uten progresjonsstolper.
Ved tilgjengelighetsstørrelser stables de vertikalt. Makrofargene brukes kun
som små dekorative markører, mens tekst identifiserer næringsstoffet.
Den vedvarende «Loggfør»-handlingen og måltidenes «Legg til» åpner loggingarket.
Eksisterende krembakgrunn, plommetekst og avrundede typografi beholdes.

Kortskygger legges bare på bakgrunnsformen, aldri på containeren med tekst,
ikoner eller kontroller. Bruk `CardContainer` for ordinære kort og
`matLoggCardSurface()` for flater med egen padding eller farge. Modifieren
samler radius, kant og myk skygge; ikke kopier skyggeverdier til featureviews.
Bilder og skannerrammer kan ha egne, tilsiktede skygger.

### Input

Et felt har synlig etikett, enhet og valideringsmelding nær feltet. Feil skal
ikke kommuniseres bare med rød ramme. Numerisk input må støtte norsk desimaltegn
og bevare brukerens verdi hvis lagring feiler.

## Tilstander

Alle gjenbrukbare mønstre og vesentlige skjermer skal ha eksplisitte varianter:

- loading
- tom
- offline eller ventende synk
- feil med retry eller alternativ
- deaktivert med forståelig årsak
- valgt
- suksess
- manglende bilde eller næringsverdi

Placeholderinnhold skal ikke kunne forveksles med ekte næringsdata. Ventende
synk vises som lokalt lagret, ikke som en mislykket registrering.

## Ernæringsdata og kilde

- vis råverdiens enhet og porsjonsgrunnlag, for eksempel «per 100 g»
- skalerte verdier må kunne forstås som beregnet fra valgt mengde
- ikke vis `0` når verdien egentlig mangler
- merk brukeroppgitte produkter og ikke-verifiserte data tydelig
- kildeinformasjon er sekundær i hierarkiet, men skal være tilgjengelig
- avrund ved visning; bevar råverdien i modellen

## Næringsverdier og valgfrie mål

Kalorier og tilgjengelige makroverdier vises konsekvent sammen med relevant
mengde, porsjonsgrunnlag og kilde. VoiceOver skal lese de samme verdiene som er
synlige. Når brukeren ikke har opprettet mål, vises næringsverdier uten
målprogresjon, gjenstående-verdi eller konstruerte plassholdere.

## Bevegelse, haptikk og lyd

Bevegelse skal forklare overgang eller bekrefte handling. Respekter redusert
bevegelse, og unngå pulsering eller fargeskift som er nødvendig for å forstå
resultatet.

Haptikk og lyd er valgfrie tilleggssignaler. De skal følge brukerens innstilling
og aldri erstatte synlig eller opplest bekreftelse.

## Tilgjengelighet

- normal tekst minst 4,5:1 kontrast
- stor tekst og meningsfulle UI-elementer minst 3:1 kontrast
- logisk leserekkefølge og presise VoiceOver-etiketter
- ikoner som gjentar synlig tekst skjules for tilgjengelighet
- ikonknapper får en meningsfull etikett
- valgt, deaktivert og feil uttrykkes med mer enn farge
- viktig informasjon og handling tåler store tilgjengelighetsstørrelser

## Endre designsystemet

Før et nytt token eller en ny delt komponent innføres:

1. kontroller om et eksisterende semantisk token eller komponent dekker behovet
2. dokumenter formålet, ikke bare den visuelle verdien
3. verifiser lys/mørk modus, kontrast, Dynamic Type og VoiceOver
4. legg verdien i `MatLogg/DesignSystem/`, ikke i featureviewet
5. oppdater dette dokumentet dersom regelen eller skalaen endres
6. legg en varig produkt-/designbeslutning i `decisions.md` ved større avvik

### Bunnmeny

Bunnmenyen viser Hjem, Søk, Loggfør, Oversikt og Profil. Loggfør er en
handling som åpner loggingarket og beholder valgt hovedfane. Den korallfargede
knappen er 56 pt med diskret kant og myk skygge. Valgt hovedfane markeres med
`action`, kraftigere tekst og fylt ikon der symbolet har en slik variant.
På iOS 26 og nyere bruker den egendefinerte bunnmenyen systemets Liquid Glass
som en avrundet, flytende navigasjonsflate. Eldre systemversjoner beholder den
varme, ugjennomsiktige `surface`-flaten. Loggfør-knappen forblir en tydelig,
korallfarget primærhandling i begge variantene.
Etiketter bruker skalerbar caption-typografi også ved tilgjengelighetsstørrelser.
Ved tilgjengelighetsstørrelser ruller menyen horisontalt, slik at hele etiketter
får plass uten skalering eller oppdeling av ordene. Menyens målte høyde gir
rulleklaring for innholdet over menyen.
Alle knapper har minst 44 pt trykkflate og fullstendige VoiceOver-navn.
Søk skjuler menyen mens søkefeltet redigeres.

### Måltidsdetaljer på Hjem

Måltidsnavn bruker sectionTitle; matnavn bruker bodyEmphasis og kan bryte over
flere linjer. Mengde står som sekundær tekst ved produktbildet. Måltidets
samlede kcal vises over tre diskrete makroetiketter med eksisterende makrofarger
på 12 % tonet bakgrunn og deepInk-tekst. Etikettene stables når bredden ikke
rekker. VoiceOver leser totalen med fulle næringsnavn. Ingen ekstra
progresjonsstolper eller måltidskvote introduseres.

Vann på Hjem vises nederst i samme `warmSurface`-flate som næringsfeltet,
med felles 20 pt padding og 24 pt hjørner. En `separator`-linje skiller delene;
ingen kort legges inni kortet. Når energi og mål er skjult, vises bare vannraden.
Raden viser «Husk å drikke vann» og «Du har drukket x glass i dag», med antall
glass fremhevet i statuslinjen. Ved null glass vises «Ingen glass registrert
i dag». Andre datoer bruker «Du registrerte x glass denne dagen» eller
«Ingen glass registrert denne dagen». Raden har minus-/plussknapper formet som glass uten hank, med svakt skrå
sider og avrundede hjørner. Begge har 44 × 44 pt rektangulær trykkflate og bruker
`mutedSurface` og `separator`. Bare dråpen bruker `info`; tekst bruker
`deepInk` og `textSecondary`. Ingen glassrutenett vises på Hjem.
Teksten brytes over flere linjer ved liten bredde, mens knappene beholder sin
plass til høyre. Ved tilgjengelighetsstørrelser i Dynamic Type stables innholdet.
Lasting, lokal feil med
retry og justering beholdes uavhengig av næringsfeltets tilstand. Teksten og
dråpen er ikke trykkbare; vannloggen justeres bare med pluss-/minusknappene.
Minuskoppen er alltid synlig og vises dempet og deaktivert ved null glass.

### Måltidsrom

Dagsloggen viser alle måltider uten måltidsvelger. Hvert måltid samles i én
lys `surface`-kortflate med 24 pt kontinuerlige hjørner, 16 pt skjerminnrykk
og luft mellom kortene. Overskrift, «Legg til» og tomtilstand inngår i kortet;
varer skilles med diskrete linjer uten egne kort.
Produktbilder er 52 pt med 2 pt innvendig luft og hele varen synlig; matnavn og mengde står over en sekundær næringslinje.
Radene har 10 pt vertikal padding uten ekstra vertikale List-innrykk.
Trykk på raden, VoiceOver-handlingen Rediger og sveiping åpner redigering;
ingen separat Endre-knapp vises. Et kompakt warmSurface-
felt rett under måltidsnavn og antall varer viser måltidets næring. Rader beholder systemets List-
sveiping, skalerbar typografi og matLoggTabBarScrollClearance().

### Vekt på Utvikling

Vektkortet fremhever siste registrering med `heroValue` og norsk dato med år.
Verdier og historikk bruker nøytrale tekstfarger uansett vektendring.
«Registrer vekt» åpner datofelt, et synlig merket kg-felt og lagrehandling.
Tomtilstanden forklarer at registrering er valgfri. De tre siste registreringene
vises med dato og verdi; ved tilgjengelighetsstørrelser stables disse.
Hver rad har en egen sletteknapp med minst 44 pt trykkflate og et VoiceOver-navn
som identifiserer registreringen. Bekreftelsen viser dato og vekt før sletting.
«Se alle registreringer» åpner Vekthistorikk i fanens navigasjonsstakk med
alle lokale registreringer, nyeste først. Historikken bruker samme rader og
slettebekreftelse som kortet, viser tomtilstand etter siste sletting og holder
innholdet over bunnmenyen med `matLoggTabBarScrollClearance()`.

### Farge for Nutri-Score-bidrag

`nutritionPositiveContribution` (grønn) og `nutritionNegativeContribution`
(rød) brukes bare på fylte poengsegmenter i beregningsforklaringen. De betyr
pluss-/minusbidrag til Nutri-Score, ikke matens trygghet eller teknisk status.
Tekst, poengtall og kortbakgrunn forblir nøytrale. Begge tokens har egne
lys-/mørkmodusverdier; teksten forklarer alltid signalet uten farge.

Produktinformasjon viser bearbeidingsgrad på kortets nøytrale `surface`,
med `bodyEmphasis` for etiketten. Gyldig klassifisering vises som en brikke
med gruppenavn og NOVA-nummer, `secondaryEmphasis`/`ink`, 12 pt horisontal
og 8 pt vertikal padding og 12 pt hjørneradius. Bakgrunnen bruker
`processingUltraSurface` for NOVA 4 og `processingNonUltraSurface` for NOVA 1–3.
Teksten kan brytes over flere linjer ved lange navn og Dynamic Type.
Manglende klassifisering vises som «Ikke tilgjengelig» uten NOVA-nummer,
med samme brikkeform og tekststil på nøytral grå `processingUnknownSurface`
(lys: `#EEEEEE`, mørk: `#303030`). Raden viser «Kilde: Open Food Facts» i `caption`. Kildelenke,
hentetidspunkt og oppdatering samles under en skillelinje.
