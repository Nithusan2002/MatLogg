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
2. valgfri dagsstatus
3. søk og skanning
4. alle fire måltider: Frokost, Lunsj, Middag og Kveldsmat
5. status for lokalt lagrede endringer som venter på synk

`Kveldsmat` er presentasjonsnavnet for den kanoniske lagringsverdien `snacks`.
Måltidskort viser et begrenset sammendrag; trykk åpner den filtrerte dagsloggen.

Når målstatus er skjult eller mangler, skal matlogging fortsatt være like synlig
og brukbar. En tom dag beskrives med «Ingen logget ennå», ikke som manglende
måloppnåelse.

### Søk

Søk samler oppdagelse og gjenbruk:

- råvaresøk
- produktoppslag
- favoritter
- nylig brukte eller skannede produkter
- inngang til strekkodeskanning

Resultater skal vise navn og relevant kilde-/enhetskontekst. Ingen treff,
nettverksfeil og ingen tidligere produkter er tre forskjellige tilstander.
Navnesøk kombinerer Matvaretabellen for råvarer med Open Food Facts for
pakkevarer og merkevarer. Når eksternt søk ikke er tilgjengelig, beholdes
eventuelle lokale råvaretreff og merkes som lagrede treff.

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
- Safe Mode og kildevisning
- personvernvalg og valgfrie samtykker
- eksport, innlogging og kontosletting
- lokal/synkronisert datastatus

Destruktive handlinger skal forklare hva som slettes lokalt, hva som skjer på
serveren og eventuell retensjonsperiode før brukeren bekrefter.

## Kjerneflyter

### Gjenbruk av gårsdagens måltid

Et tomt måltidskort kan vise gårsdagens matvarer og mengder med «Loggfør»,
«Juster» og «Ikke nå». Brukeren velger selv; appen skriver aldri automatisk.
En kvittering med «Angre» vises etter atomisk lokal lagring. Forslaget fungerer
uten nett og uten synlige kalorier eller mål. Detaljer og tilstander er samlet
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
  → logg inn eller opprett konto
  → se kort forklaring av mål, databruk og personvern
  → angi eller hopp over valgfrie person- og vektopplysninger
  → velg veiledende energi- og makromål
  → velg trygghets-/visningspreferanser
  → Hjem
```

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

Når mål eller Trygg modus er aktivert som skjuling, erstattes skjemaet med en
kort forklaring om visningsvalget og veien til Innstillinger. Ingen måltall,
inputfelt eller forslag finnes i tilgjengelighetstreet. Når bare kalorier er
skjult, kan eksisterende makromål redigeres; kalorimålet beholdes. Opprettelse av
nye mål og beregning av forslag krever at kalorivisning er slått på.

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
Ingen treff på strekkode
  → forklar at produktet ikke ble funnet
  → skann igjen, søk eller opprett manuelt
  → oppgi navn og dokumenterte næringsverdier
  → vis kilde som brukeroppgitt
  → lagre lokalt og fortsett til mengde
```

Manglende verdier skal ikke fylles med antakelser. Skjemaet skal skille mellom
påkrevd og valgfritt innhold og forklare feil ved feltet.

### Offline og synk

```text
Bruker lagrer uten nett
  → lagre data og synkhendelse atomisk lokalt
  → bekreft at registreringen er lagret på enheten
  → vis diskret ventende synkstatus
  → forsøk synk når nett er tilbake
```

Synkstatus er sekundær så lenge brukeren kan fortsette. En serverfeil skal ikke
overskrive eller skjule en vellykket lokal lagring.

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

## Safe Mode

Safe Mode er et sammenhengende presentasjonsvalg:

- skjulte kalorier og mål fjernes også fra tilgjengelighetstekst
- plassholdere skal ikke avsløre at en verdi finnes
- logging, mengde, måltid og kilde skal fortsatt fungere
- skjermen skal ikke få tomme hull eller etiketter som «skjult mål»
- innstillingen skal påvirke alle relevante skjermer konsekvent

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
- Safe Mode og tilgjengelighet er kontrollert
- varige nye mønstre eller tokens er dokumentert i designsystemet
- implementert status og relevante detaljspesifikasjoner er oppdatert
