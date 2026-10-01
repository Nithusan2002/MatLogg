# MatLogg – design- og brukerflyt

Dette er den normative, overordnede UX-retningen for MatLogg. Dokumentet
beskriver brukerbehov, informasjonsarkitektur, handlingshierarki og tilstander.
Detaljerte brukerhistorier, tekstskisser og mikrointeraksjoner under `docs/specs/`
er underlag og må oppdateres dersom de strider mot dette dokumentet.

Faktisk implementasjon beskrives i [current-state.md](current-state.md). Visuelle
regler og tokens beskrives i [design-system.md](design-system.md).

## Opplevelsesmål

MatLogg skal oppleves rask, rolig, varm og troverdig. Brukeren skal kunne
loggføre en kjent matvare med få valg, samtidig som mengde, måltid, enhet og
kilde er forståelige før lagring.

Designet skal støtte registrering, ikke evaluere brukeren. Kalorier, vekt og mål
er valgfrie informasjonslag og skal aldri brukes til skam, alarmisme eller
pressende budskap.

## Designprinsipper

1. **Én tydelig primærhandling.** På tvers av appen er «Loggfør» den viktigste
   gjentatte handlingen.
2. **Oversikt før detaljer.** Hjem viser dagens status og måltider; redigering og
   full næringsinformasjon åpnes ved behov.
3. **Forutsigbart neste steg.** Vis valgt måltid før valg av matvare og behold
   brukerens input ved feil.
4. **Local-first skal merkes som trygghet.** Bruk «lagret på enheten» og «venter
   på synk», aldri formuleringer som antyder at gyldige lokale data er tapt.
5. **Kilde før sikkerhetspåstand.** Vis hva verdien bygger på. Ikke kall
   brukeropprettede eller eksterne data verifiserte uten faktisk grunnlag.
6. **Rolig fremgang.** Nøytrale formuleringer erstatter «bra», «dårlig»,
   «overskredet» og andre moralske vurderinger av matinntak eller vekt.
7. **Tilgjengelig i alle tilstander.** Normal, loading, tom, offline, feil,
   deaktivert, suksess og ekstreme data inngår i designet.

## Informasjonsarkitektur

### Hjem

Hjem svarer på «Hva har jeg registrert i dag?» og gir rask vei til ny logging.
Datoen kan flyttes én dag om gangen med piler eller velges fra en kalender.
Fortidige og fremtidige datoer kan velges. Valgt dato gjelder både
dagsoversikten, måltidslisten og nye registreringer, og vises derfor også i
loggføringsflyten. En fremtidig registrering er en vanlig datert logg; den
utløser ikke automatisk logging, varsling eller en egen måltidsplan.

Prioritet:

1. dato og kontekst
2. valgfri dagsstatus uten egen overskrift eller gjentatt dato
3. alle fire måltider: Frokost, Lunsj, Middag og Kveldsmat
4. kontekstuelle legg-til-handlinger og personlige hurtigvalg
5. status for lokalt lagrede endringer som venter på synk

`Kveldsmat` er presentasjonsnavnet for den kanoniske lagringsverdien `snacks`.
Måltidskort viser et begrenset sammendrag; trykk åpner den filtrerte dagsloggen.
Generiske søk- og skanneknapper vises ikke som en egen rad på Hjem. Den
vedvarende «Loggfør»-handlingen åpner disse valgene, mens legg-til fra et
måltidskort beholder måltidet som kontekst. Personlige hurtigvalg kan fortsatt
vises på Hjem fordi de gir en kortere flyt enn generisk søk.

Når målstatus er skjult eller mangler, skal matlogging fortsatt være like synlig
og brukbar. En tom dag beskrives med «Ingen logget ennå», ikke som manglende
måloppnåelse.

### Vann på Hjem

Et kompakt vannkort ligger etter valgfri dagsstatus og før måltidene. «Ett
glass» lagrer én registrering direkte for valgt dato, også uten nett og konto.
Kortet viser dagens antall uten kvitteringstekst eller angreknapp, og tilbyr
«Fjern ett glass» ved trykk på antallet. En synlig minusknapp ved siden av plussknappen
fjerner siste glass med ett trykk uten dialog. Den er deaktivert ved null,
under lasting og mens en lagring pågår. Ingen antatt ml-mengde, mål eller påminnelser.
Ny dag viser null uten å slette historikken. Feil viser retry uten å øke telleren.
Vannkortet bruker et tydelig antall under en liten overskrift, to like store, runde
ikonknapper for pluss og minus. Pluss har en dempet blå bakgrunn; minus en
nøytral bakgrunn. Begge har 44 × 44 punkters trykkflate og tydelig VoiceOver-tekst. Kopper har nøytralt omriss
og blått gradert vann når de er fylt. Vannkortet viser ti tomme kopper fra start, fordelt på to rader med fem.
Én kopp fylles med blått vann per registrert glass. Etter ti legges flere fylte
kopper til, fem per rad. Minusknappen tømmer siste kopp; ekstra kopper
fjernes når antallet faller. Ti er en startlayout, ikke et anbefalt dagsmål;
ingen «av ti», prosent eller målfeiring vises. Fyll og teller animeres kort.
«Reduser bevegelse» gir umiddelbar oppdatering. VoiceOver leser antallet én
gang og hopper over dekorasjonen.
Store tekststørrelser flytter knappen til neste rad. Vann følger aktiv profileier,
og inngår i eksport, kontooverføring og sletting.

### Søk

Søk-fanen har et direkte søkefelt og én separat, tekstmerket inngang til
strekkodeskanning. Tastaturet åpnes først når feltet aktiveres. Bunnmenyen skjules
mens søkefeltet redigeres, slik at den ikke dekker treff over tastaturet, og vises
igjen når redigeringen avsluttes. Søk fra Loggfør
bruker samme skjerminnhold i en egen presentasjon med fokusert søkefelt.

Før søk vises favoritter, inntil seks nylig **loggede** varer og et begrenset
utvalg råvarer. Alle produktrader åpner mengdevalg og loggføring. Favoritter og
nylig brukt følger aktiv profileier og oppdateres ved retur fra produktdetaljer
og når skjermen vises igjen.

Navnesøk kombinerer den lokale Matvaretabellen-katalogen og tilgjengelige lagrede
produkter med Open Food Facts for pakkevarer og merkevarer. Lokale treff vises
mens brukeren skriver. Eksternt navnesøk starter først ved «Søk» eller innsending
fra tastaturet. Lokale treff beholdes mens flere produkter hentes og ved nettfeil.
Private produkter fra andre profiler er ikke søkbare.

Resultater viser navn, eventuelt merke og bilde, samt kilde-/enhetskontekst.
Innledende lasting, lesefeil, ingen tidligere produkter, ingen lokale treff og
ingen eksterne treff har ulike tilstander. Feil tilbyr retry uten å tømme søket.
Skanning og fungerende manuell produktregistrering er tilgjengelige alternativer.
Manuell registrering lagrer et brukeroppgitt produkt før mengdevalg og logging.

### Loggfør

Den sentrale faneknappen heter «Loggfør» og åpner et bunnark uten å endre valgt
hovedfane. Arket viser alltid «Logg til: [måltid]» og tilbyr:

1. søk etter matvare
2. skann strekkode
3. manuell registrering
4. hurtigvalg fra favoritter og nylig brukt

Lagrede måltider vises før enkeltvarer når de finnes. De to innholdstypene har
egne seksjonsoverskrifter, og en måltidsrad viser antall varer i tillegg til
måltidsikon og innholdsoppsummering. En lagret mal åpnes i en forhåndsvisning
med matvarer, mengder, valgt dato og måltidskategori før den loggføres.
Oppretting skjer fra menyen til et allerede registrert måltid. Se [lagrede
måltider](saved-meals.md).

Tidspunkt kan foreslå et måltid. Inngang fra et måltidskort overstyrer forslaget.
Brukeren kan alltid endre måltid før lagring.

### Oversikt

Oversikt er valgfri og skal være nøytral. Den kan vise vektregistrering,
historikk og graf, men skal ikke bruke gratulasjoner, advarsler eller farge alene
til å vurdere vektendring. Sletting krever en tydelig bekreftelse.

### Profil

Profil samler:

- personlige detaljer
- mål og visning av målstatus
- kildevisning
- personvernvalg og valgfrie samtykker
- eksport, innlogging og kontosletting
- lokal/synkronisert datastatus

Profil viser ett målkort med eksplisitt redigering, uten dupliserte tallkort.
Personlige detaljer redigeres som et utkast med Avbryt/Lagre. Navn vises i
gruppen «Profil». Fødselsdato, kjønn, høyde, vekt og aktivitetsnivå
samles i «Grunnlag for målforslag», med en felles «Hvorfor spør vi?»-forklaring.
Alle opplysningene er valgfrie; brukeren kan også sette mål selv.
Et valgfritt visningsnavn lagres per profil på enheten, uten synk, og vises i profilkortet
foran eventuelt navn fra kontoen. Tom fødselsdato
bevares som tom, ugyldige tall avvises ved feltet, og lagringsfeil beholder
utkastet på skjermen. Vekt her er beregningsgrunnlag, ikke en vektregistrering.
Endrede opplysninger endrer ikke eksisterende mål automatisk. Målveiviseren
kan åpne Personlige detaljer når beregningsgrunnlaget mangler.

Eksport under Innstillinger inneholder matlogg, vann, lagrede måltider,
gjeldende daglige mål, vekthistorikk, personlige detaljer og favoritter for
aktiv profileier. Den viser fremdrift og feil og beskrives som JSON-eksport
av disse datasettene, ikke som en gjenopprettbar sikkerhetskopi eller komplett
kontoeksport. Kontohandlinger og slettemekanismene endres ikke i denne flyten.

Destruktive handlinger skal forklare hva som slettes lokalt, hva som skjer på
serveren og eventuell retensjonsperiode før brukeren bekrefter.

## Kjerneflyter

### Gjenbruk av gårsdagens måltid

Et tomt måltidskort kan vise gårsdagens matvarer og mengder med «Loggfør»,
«Juster» og «Ikke nå». Lagret kcal vises sekundært for hver vare, også for
VoiceOver. Brukeren velger selv; appen skriver aldri automatisk. En kvittering
med «Angre» vises etter
atomisk lokal lagring. Forslaget fungerer uten nett. Detaljer og tilstander er
samlet
i [måltidsgjenbruk](meal-reuse.md).

### Lagrede måltider

Et registrert måltid kan lagres som en navngitt mal. Malen beholder matvarer,
mengder, næringsgrunnlag og kilde, men er uavhengig av historiske logger.
Brukeren kontrollerer alltid dato, måltidskategori og mengder før eksplisitt
logging. Forhåndsvisningen bruker en kompakt destinasjonsrad, mengder med synlig
enhet og en fast hovedhandling nederst; kilden er sekundær informasjon.
Enkeltlogger redigeres i samme visuelle mønster og bruker presentasjonsnavnet
«Kveldsmat». Alle nye logger lagres atomisk og kan angres samlet. Se [lagrede
måltider](saved-meals.md).

### Førstegangsbruk

```text
Åpne appen
  → fortsett på denne iPhonen, eller logg inn med Apple/e-post
  → se kort forklaring av lokal lagring, valgfrie opplysninger og avgrensning
  → velg kun loggføring, eller sett opp et valgfritt mål
  → oppgi eller hopp over beregningsgrunnlag; appen gjetter aldri manglende data
  → kontroller eventuelt estimert energi- og makromål
  → se personvernvalg og en oppsummering
  → Hjem
```

Velkomstskjermen skal vise budskap, trygghetspunkter og primærhandling uten
scrolling på en vanlig iPhone i standard tekststørrelse. Innholdet ligger fortsatt
i en scrollbar beholder som tilgjengelighetsfallback for små skjermer, liggende
retning og store tekststørrelser. «Start uten mål» og «Kun loggføring» skal ikke
opprette et skjult kalorimål i bakgrunnen.

Lokal bruk er fullverdig og tidsubegrenset. Konto er et valgfritt valg på
velkomstskjermen og i Profil. Konto skal ikke omtales som sikkerhetskopi eller
flerenhetssynk før servernedlasting og gjenoppretting er implementert. Hvis en
lokal profil med data logger inn, må brukeren bekrefte før dataene atomisk
knyttes til kontoen. Utlogging skjuler kontodataene på enheten; de blir ikke
synlige for en ny lokal profil.

Målberegninger skal merkes som veiledende. Onboarding skal ikke love medisinsk
effekt eller gjøre vekt obligatorisk når funksjonen kan fungere uten.

### Redigere daglige mål

Profil → Daglige mål åpner et skjema med lagrede kalorier og makromål i gram.
Verdiene beholdes nøyaktig, også ved lagring uten endringer. «Avbryt» forkaster
utkastet. «Lagre endringer» validerer feltene, lagrer lokalt og bekrefter
«Målene er lagret på enheten». Ved feil beholdes utkastet, og brukeren kan prøve
igjen. Under lagring er redigering og gjentatte lagretrykk deaktivert.

«Beregn nytt forslag» åpner en separat veiviser med måltype, tempo,
aktivitetsnivå og makrofordeling. Den bruker lagrede personopplysninger når
beregningsgrunnlaget er gyldig. Et automatisk forslag krever gyldig vekt,
høyde, alder 18+ og valg av kvinne- eller mannvarianten i voksenformelen.
Ved manglende eller annet formelgrunnlag skal appen ikke gjette et generelt
kaloritall; brukeren kan oppdatere Personlige detaljer eller angi eget mål.
«Bruk forslaget» endrer bare utkastet; vanlig lagring kreves etterpå. Veiviseren
oppdaterer ikke personopplysninger. Førstegangsoppsett bruker fortsatt onboarding.

Forslaget omtales som et «estimert startpunkt», ikke som en anbefaling eller
fasit. Standardprofilene for makroer ligger innenfor NNR 2023-intervallene for
voksne: Balansert 15/50/35, Mer protein 20/45/35 og Mer karbohydrat 15/55/30
energiprosent for protein/karbohydrat/fett. Egendefinerte gramverdier beholdes.

Målskjermen viser alltid kalori- og makrofelt. Har brukeren ikke opprettet mål,
forklarer tomtilstanden at egne verdier eller et veiledende forslag kan brukes.
Ingen mål opprettes før brukeren eksplisitt lagrer.

Feltene har synlige etiketter og enheter, norsk desimaltegn og feil ved feltet.
Skjermen ruller ved tastatur og stor tekst. Eksisterende `CardContainer`,
`PrimaryButton`, typografi og semantiske farger brukes uten nye design-tokens.

### Logge en kjent matvare

```text
Trykk Loggfør eller åpne et måltid
  → bekreft måltid
  → søk, skann eller velg hurtigvalg
  → kontroller produkt, mengde, enhet, næringsverdi og kilde
  → trykk Legg til
  → lagre domenedata og synkhendelse lokalt
  → lukk produktarket og vis en kompakt bekreftelse med Angre
  → fortsett i opprinnelig kontekst; skanneren er klar for neste vare
```

Mengde foreslås når datagrunnlaget tillater det, men skal kunne redigeres. Ved
lagringsfeil beholdes mengde og måltid, og «Prøv igjen» vises ved handlingen.
Vellykket lagring bekreftes med vare, mengde, måltid og «Lagret på enheten».
Bekreftelsen er ikke-modal, forsvinner etter fire sekunder og tilbyr Angre.

### Skanning

```text
Start skanning
  → be om kameratilgang ved behov
  → les strekkode
  → gi diskret visuell/haptisk bekreftelse
  → slå opp lokalt og eksternt
  → åpne produktdetalj eller ukjent-produkt-flyt
```

Ved manglende kameratilgang forklares hvorfor tilgangen trengs, med vei til
Innstillinger og søk/manuell registrering som reelle alternativer.

### Ukjent produkt

```text
Velg «Opprett egen matvare» eller få nulltreff/ukjent strekkode
  → behold dato, måltid og eventuell strekkode
  → oppgi navn, merke og per 100 g / 100 ml
  → ta bilde av næringstabell eller skriv manuelt
  → kontroller og korriger alle foreslåtte verdier
  → legg eventuelt til forsidebilde
  → velg privat (standard) eller eksplisitt bidrag til felleskatalog
  → lagre produkt og synkhendelse atomisk lokalt
  → vis kilde som «Brukeroppgitt»
  → fortsett til mengde og logging
```

Manglende verdier skal ikke fylles med antakelser. Skjemaet skal skille mellom
påkrevd og valgfritt innhold og forklare feil ved feltet. Ufullstendige private
utkast kan lagres, men kan ikke logges eller publiseres. AI er en valgfri,
redigerbar assistent; et forslag er aldri en bekreftet eller medisinsk verdi.
Etikettbilder er private. Felleskatalogen viser publiserte bidrag som
«Felleskatalog · Ikke verifisert» frem til moderator godkjenner dem.

### Offline og synk

Den normative funksjonslisten, konfliktavgrensningen og statusmatrisen finnes i
[offline-adferd og synkstatus](offline-behavior.md).

```text
Bruker lagrer uten nett
  → lagre data og synkhendelse atomisk lokalt
  → bekreft at registreringen er lagret på enheten
  → vis diskret ventende synkstatus
  → forsøk synk når nett er tilbake
```

Synkstatus er sekundær så lenge brukeren kan fortsette. En serverfeil skal ikke
overskrive eller skjule en vellykket lokal lagring. «Alt synkronisert» skal ikke
brukes uten presisering så lenge kontrakten bare bekrefter denne enhetens
opplastingskø.

## Skjermtilstander

Alle nye eller vesentlig endrede skjermer skal definere:

| Tilstand | Krav |
| --- | --- |
| Loading | Behold skjermstruktur; ikke blink en tomtilstand først. |
| Tom | Forklar hva området er til for og tilby relevant neste handling. |
| Offline | Fortell hva som fortsatt virker, og hva som venter. |
| Feil | Forklar problemet uten skyld; behold input og tilby retry eller alternativ. |
| Suksess | Bekreft kort hva, mengde og måltid som ble lagret. |
| Deaktivert | Forklar årsaken når den ikke er åpenbar; bruk ikke bare redusert opacity. |
| Ekstreme data | Støtt lange navn, store verdier, manglende næringsstoffer og mange logger. |

## Næringsvisning uten mål

Kalorier og tilgjengelige makroverdier vises konsekvent. Brukere som velger kun
loggføring får næringsoversikt uten målprogresjon. Måltall, gjenstående-verdi og
progresjonskomponenter vises først når et mål er eksplisitt opprettet.

## UX-tekst

Bruk kort, konkret norsk og handling først:

- «Loggfør mat»
- «Logg til: Lunsj»
- «Lagret på enheten – venter på synk»
- «Vi fant ikke denne strekkoden»
- «Prøv igjen»
- «Ingen logget ennå»

Unngå:

- moralske vurderinger av matinntak eller kroppsvekt
- absolutte helseløfter
- «Du har feilet», «dårlig dag» eller «overskredet målet»
- å kalle estimater eller brukeroppgitte verdier dokumenterte fakta

## Tilgjengelighetskrav

- effektiv trykkflate på minst 44 × 44 pt
- Dynamic Type uten tap av kritisk informasjon eller handling
- logisk VoiceOver-rekkefølge og meningsfulle etiketter
- normal tekst minst 4,5:1 kontrast; stor tekst og meningsfulle UI-elementer
  minst 3:1
- status uttrykkes med tekst eller ikon i tillegg til farge
- redusert bevegelse respekteres; animasjon er aldri nødvendig for forståelse
- haptikk og lyd er tilleggssignaler og kan slås av

## Akseptansekriterier for varige UX-endringer

En ny eller endret flyt er ikke ferdig før:

- brukerbehov og primærhandling er dokumentert
- loading, tom, offline, feil og suksess er vurdert
- lokal lagring og eventuell synk er tydelig skilt
- kilde, måleenhet og manglende data håndteres uten gjetting
- synlige næringsverdier og tilgjengelighetstekst samsvarer
- varige nye mønstre eller tokens er dokumentert i designsystemet
- implementert status og relevante detaljspesifikasjoner er oppdatert

### Sletting av enkeltvarer i matloggen

Enkeltvarer slettes uten bekreftelsesdialog. En kompakt melding over bunnmenyen
tilbyr «Angre» i fire sekunder (åtte med VoiceOver). Flere raske slettinger
samles og kan gjenopprettes atomisk med samme mengde, enhet, næringsgrunnlag
og tidspunkter. Gjenoppretting bruker nye logg-ID-er for å tåle forsinkede
slettehendelser. Bekreftelser for større slettinger beholdes.
