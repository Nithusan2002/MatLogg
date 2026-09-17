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
7. Ernæringsstatus, mål og vekt skal presenteres nøytralt. Safe Mode skal være
   konsekvent i både synlig UI og tilgjengelighetstre.

## Farger

Fargene defineres semantisk i `MatLogg/DesignSystem/Colors.swift`.

| Token | Formål |
| --- | --- |
| `background` | Sidens grunnflate. |
| `surface` | Kort, skjema og ordinære innholdsflater. |
| `warmSurface` | Varm sekundær fremheving. |
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
| `hero` | Kort hovedutsagn eller stor sidetittel. |
| `title` | Skjerm- og hovedkorttitler. |
| `sectionTitle` | Seksjonsoverskrifter. |
| `body` | Brødtekst og ordinære verdier. |
| `bodyEmphasis` | Handlinger, feltnavn og fremhevet brødtekst. |
| `caption` | Metadata, kilde og støttetekst. |
| `captionEmphasis` | Kompakte etiketter og status. |

Den avrundede systemtypografien er del av MatLoggs vennlige uttrykk. Lange
forklaringer skal ikke bruke tunge displaystiler. Kritiske krav, kilder og feil
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

## Safe Mode og sensitiv informasjon

Når kalorier eller mål skjules, fjernes de fra:

- synlig tekst
- diagrammer og etiketter som avslører verdien
- VoiceOver-labels og accessibility values
- tomme plassholdere som antyder skjult innhold

Mengde, måltid, produktnavn og kilde skal fortsatt være tilgjengelig. Safe Mode
skal ikke endre eller slette underliggende brukerdata.

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
