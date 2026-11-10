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
| `energySurface`, `energySurfaceEnd`, `energySurfaceGradient` | Korallsol: diagonal korall–aprikos-gradering for dagsstatuskortet på Hjem og i dagsloggen (`#FFB5B9` → `#FFD8AE` i lys modus, `#542C33` → `#443121` i mørk modus). Flaten er lik uansett målstatus; vann beholder blå detaljer. |
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
| `chartLabel`, `chartLabelEmphasis` | Kompakte diagrametiketter med skalerbar caption2-typografi. |
| `caption` | Kompakt metadata og korte, mindre sentrale etiketter. |
| `captionEmphasis` | Kompakte etiketter og status. |

Typografien følger godkjent prototype 10: kraftige, avrundede hovedoverskrifter,
avrundede titler og seksjonsoverskrifter med halvfet vekt, og vanlig systemfont
i brødtekst, matvarenavn og metadata. Store næringsverdier bruker `heroValue`
med middels vekt og tabellariske sifre. Den kompakte Utvikling-prototypen bruker
`hero` for hovedtallet og `metricValue` for de små metrikktallene.
Native tekststiler bevarer Dynamic Type;
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
alltid kan rulles helt over den egendefinerte bunnmenyen. Ved
tilgjengelighetsstørrelser vises fanene over to rader med Loggfør på en
egen rad mellom dem.

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
- primærknappen har normalt 56 pt minimumshøyde uten ekstra vertikal padding; den vokser med tekstinnholdet
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

Vann vises nederst i dagsstatuskortet på Hjem og i dagsloggen,
med felles 20 pt padding og 24 pt hjørner. En `separator`-linje skiller delene;
ingen kort legges inni kortet. Når energi og mål er skjult, vises bare vannraden.
Raden viser «Husk å drikke vann» og «Du har drukket x glass i dag», med antall
glass fremhevet i statuslinjen. Ved null glass vises «Ingen glass registrert
i dag». Andre datoer bruker «Du registrerte x glass denne dagen» eller
«Ingen glass registrert denne dagen». Raden har minus-/plussknapper formet som glass uten hank, med svakt skrå
sider og avrundede hjørner. Begge har 44 × 44 pt rektangulær trykkflate og bruker
`mutedSurface` og `separator`. Bare dråpen bruker `info`; tekst bruker
`deepInk` og `textSecondary`. Kortet har ikke glassrutenett.
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

Søk viser «Ferdig» i navigasjonslinjen når søkefeltet har fokus.
Handlingen lukker tastaturet uten å sende et søk. Keyboard-toolbar brukes
ikke på denne flaten, etter fysisk verifisert layoutadvarsel fra SwiftUIs
InputAccessoryBar ved introovergangen på iOS 27.0.

Pilot 8. oktober 2026: Kontoskjermen viser Apple-innlogging og forklaringen
om lokal lagring. Når e-postauth er av, skjules felter, e-posthandlinger,
registreringslenke og «eller»-skille samlet. Bruk eksisterende typografi,
farger og Apple-knapp; ingen ny deaktivert e-posthandling vises.

### Konsistens i Profil og Utvikling

Hovedskjermene bruker 16 pt horisontalt innrykk og 16 pt mellom
innholdsgrupper. Favoritter bruker den delte `matLoggCardSurface()`-stilen.
Ukediagrammets etiketter bruker `chartLabel`/`chartLabelEmphasis` og stables
vertikalt ved tilgjengelighetsstørrelser, slik at sju kolonner ikke begrenser
lesbarheten ved stor tekst.

### Produktbilde i mengdevalg

Produktkortets mengdevalg viser den store bildeflaten bare når et bilde er
tilgjengelig. Manglende bilde, pågående lasting og lastefeil reserverer ingen
bildeflate; navn, mengde og næringsinnhold kommer høyere opp. Et lastet bilde
beholder eksisterende størrelse, stil og forhåndsvisning. Andre bildeflater og
lister beholder sine eksisterende plassholdere.

### Kompakt søketopp

Søkefelt og søkeknapp deler rad ved vanlig tekststørrelse. De sekundære
handlingene Skann strekkode og Registrer manuelt bruker `secondaryEmphasis`
og minst 44 pt høyde på raden under. Store tekststørrelser bruker stablede
kontroller i den scrollbare listen. Et tomt statusfelt reserverer ingen høyde.

### Felles felt- og skjemaflater

Tekstfelt utenfor native skjemarader bruker `matLoggInputStyle()` med
`surface`, `ink`, 12 pt padding, minst 48 pt høyde og 12 pt hjørner.
`matLoggFieldSurface()` gir samme flate og `controlBorder` til sammensatte
felt og knapper som åpner inputvalg, uten å endre deres layout.
Native `Form` og `List` skjuler systembakgrunnen og bruker `background`
bak innholdet og `surface` på ordinære rader. Primærknapper i skjemaer
har transparent radbakgrunn. Ordinære kort bruker `CardContainer` eller
`matLoggCardSurface()`; kamera, bildeleser, delingsgrafikk og systemkontroller
beholder sine formålstilpassede flater.

### Tilpassbar hub på Utvikling (2026-11-06)

Mat og næring samt Vekt bruker hver sin ordinære `CardContainer`, med
semantisk ikon, `title`-overskrift og sekundær forklaring om registrering i
MatLogg. Dagens energi, ukediagram og makroer samles i matkortet uten kort inni
kort. Store verdier bruker `heroValue`. Kilder for underliggende matvarer
endres ikke av denne grupperingen. Ingen nye fargetokens innføres.

«Tilpass» står ved skjermtittelen og flyttes under den ved store tekststørrelser.
Tilpasningsarket bruker native List/Toggle med minst 44 pt radhøyde og
fast plassering for hver bryter. Avbryt, Lagre og Gjenopprett standard
virker på et redigeringsutkast. Huben og vekthistorikken
holder innhold over bunnmenyen med `matLoggTabBarScrollClearance()`.

### Skritt fra Apple Helse (2026-11-06)

Skritt er et valgfritt ordinært hub-kort med `figure.walk`, `heroValue` for
antallet og eksplisitt enhet. Hentetid står i detaljene. Bruk eksisterende
semantiske farger og knapper med minst 44 pt trykkflate. Loading, ikke tilkoblet,
ingen data, lesefeil, utilgjengelig enhet og demomodus har egne teksttilstander.
Ingen helsescore, daglig kvote eller belønningsfarge. Manglende data blir ikke
null. Brødtekst kan brytes ved store tekststørrelser, og VoiceOver leser antall
og «skritt». Helse-forespørselen startes bare av tilkoblingsknappen.

### Kompakt Utvikling-prototype (2026-11-06)

Den valgte prototypen er visuell referanse for faktisk UI. Matkortet samler ett
hovedtall og periodeforklaring. Dag har en vannrett makrofordeling i
appens makrofarger med gram og prosent ved hvert navn. Måned bruker et
lavt korallfarget diagram og en makrofooter.
I Dag og Måned er Skritt og Vekt små kort på samme rad ved vanlig tekststørrelse; detaljer
og kontroller ligger én navigasjon inn. Ved tilgjengelighetsstørrelser stables
kortene og makrofooteren uten å kutte tekst. Tilpass står til høyre for
skjermtittelen og flyttes til en egen linje når tittelen trenger mer plass.
Skritt, Vekt og Treningsøkter viser en pil i tittellinjen.
Treningsøkter bruker full bredde i alle posisjoner og viser inntil to
økter på kortet i Dag og Måned. Dagstall for mat ligger i et ark med
kompakte listerader.

Ukeoversikt bruker én datoakse med sju like kolonner, korallfargede
matsøyler, turkise skrittsøyler og øktmarkører. Søylediagrammene har fem svake
hjelpelinjer fra null til toppen av skalaen. Dager uten tall står tomme i
søylediagrammene. En treningsrad med tilgjengelige økter viser en liten grå
prikk på dager uten viste økter.
Ved smal bredde eller tilgjengelighetsstørrelser vises oppsummeringen over
grafen. Diagramverdier har dato og verdi i tilgjengelighetsteksten.

`metricValue` er en skalerbar, kraftig avrundet title-verdi med tabellariske
sifre for kompakte metrikker. `onAction` er kontrastfargen på fylte action-flater
(lys flate i lys modus, plomme i mørk modus). Periodeknappene bruker action/
onAction, eksplisitt valgt-trait og minst 44 pt trykkflate. Dato-pilene er
44 pt. Kortene bruker de delte skygge- og flatevariantene.

Skritt og Vekt har lik høyde på delt rad.
På egen rad for Vekt deler målingen og måledatoen bredden når teksten får plass.
Ved større tekst kan de stables. Bakgrunnen ved statuslinjen skjermer
systemikonene når oversikten rulles.
Vektlinjen vises fra to målinger i perioden og bruker bare reelle punkter.
Skrittgrafen bruker den turkise `activityChart`-fargen og vises fra to
registrerte punkter. Timer eller dager uten data gir brudd i linjen.
Detaljvisningens søyler har nullbasert akse og tilgjengelige tall per intervall.
Datakildene står i detaljene. Demomodus har én Demodata-etikett ved
skjermtittelen i Utvikling.

## Matgruppeikoner (6. november 2026)

Matvarer uten tilgjengelig bilde bruker et av 15 lokale vektorikoner i
`Assets.xcassets/FoodIcons`. Alle har samme avrundede strek, dempede aksenter og
separate lys/mørk-varianter. `ProductThumbnailView` beholder dagens flate og mål;
et lastet produktbilde prioriteres foran ikonet. Lasting og bildefeil bruker
samme kategoriikon uten feilmelding eller layoutendring.

Matvaretabellens eksplisitt støttede gruppe-ID-er og Open Food Facts sine
kategoritagger (med kategoritekst som reserve) kobles av `FoodGroupResolver`.
For havregryn og bearbeidede fjærkrevarer gir konkrete matvare-ID-er et mer
treffende ikon enn de brede gruppene i Matvaretabellen.
Ukjente eller tvetydige grupper bruker tallerkenikon. Kategorien brukes ikke
til ernæringsberegning eller til å bekrefte innholdet i maten. Råkategori og
kilde bevares. Ikonet er dekorativt for VoiceOver når raden har matvarens navn.

Egne produkter har «Matgruppe (valgfritt)» med «Ikke valgt» som standard, både
ved oppretting og i produktkortet. Valget viser en ikonforhåndsvisning, lagres
lokalt og kan tømmes. Opprettingsutkastet bevarer valget. Produktkortet endrer
bare matgruppen, ikke næringsdata, bilde, navn eller kilde.
