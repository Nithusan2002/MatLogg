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
Kalenderen åpnes som en popover ved datoknappen, med norsk språk og appens
handlingsfarge. Datovalg oppdaterer dagsoversikten umiddelbart mens kalenderen
forblir åpen, også ved måneds- og årsnavigasjon. Trykk utenfor lukker kalenderen
og beholder valgt dato. Ved tilgjengelighetsstørrelser for tekst eller lav
skjermhøyde er kalenderinnholdet scrollbart i samme popover.
Fortidige og fremtidige datoer kan velges. Valgt dato gjelder både
dagsoversikten, måltidslisten og nye registreringer, og vises derfor også i
loggføringsflyten. En fremtidig registrering er en vanlig datert logg; den
utløser ikke automatisk logging, varsling eller en egen måltidsplan.

Prioritet:

1. dato og kontekst, inkludert status for lokalt lagrede endringer
2. «Dagen din, så langt.» og samlet dagsstatus med valgfritt næringsfelt
3. vann som nederste rad i dagsstatusen, med antall glass og minus/pluss
4. «Se dagslogg» og alle fire måltider med kontekstuell «Legg til»: Frokost, Lunsj, Middag og Kveldsmat
5. personlige hurtigvalg

Måltidene vises i kompakte, lyse kort med myke hjørner og diskret skygge. Næringsfeltet bruker dagens varme tema,
kaloritall og tre makrokolonner uten progresjonsstolper. Makromål vises som
sekundær tekst; ved tilgjengelighetsstørrelser stables kolonnene vertikalt.
Næringsfeltet viser registrerte verdier også uten mål; måltekst vises bare når mål finnes.
Eksisterende visningsvalg beholdes og heter «Vis energi og mål på Hjem».

`Kveldsmat` er presentasjonsnavnet for den kanoniske lagringsverdien `snacks`.
Måltidsnavnet åpner valgt måltid for valgt dato. Synlige varerader åpner
redigering direkte. «Se dagslogg» åpner alle måltider for valgt dato.
Hurtigvalg viser favoritter og nylig loggede varer, med mengdevalg før logging.
Generiske søk- og skanneknapper vises ikke som en egen rad på Hjem. Den
vedvarende «Loggfør»-handlingen åpner disse valgene, mens legg-til fra et
måltidskort beholder måltidet som kontekst. Personlige hurtigvalg kan fortsatt
vises på Hjem fordi de gir en kortere flyt enn generisk søk.

Når målstatus er skjult eller mangler, skal matlogging fortsatt være like synlig
og brukbar. En tom dag beskrives med «Ingen logget ennå», ikke som manglende
måloppnåelse. Under måltidsoverskriften vises da «Loggfør første måltid», som
åpner eksisterende loggingark for valgt dato. Handlingen vises bare etter
vellykket lasting av en dag uten matlogger, også når målstatus er skjult.
Den skjules under lasting og ved feil. Dager med matlogger bruker den faste
«Loggfør»-handlingen i bunnmenyen og «Legg til» på måltidene.

### Vektregistrering

«Sjekk inn» er tatt ut av Hjem inntil videre (2026-10-03). Vekt registreres
valgfritt under Oversikt → Registrer vekt. Eksisterende vekthistorikk beholdes;
endringen påvirker ikke mål eller lagring. Ingen daglig innsjekk tilbys.

### Dagslogg

«Se dagslogg» på Hjem åpner dagsloggen uten måltidsfilter. Måltidsnavnene
er egne snarveier til filtrert visning. Brukeren kan velge «Se hele dagen»
eller bytte måltid eksplisitt uten å endre dato.
Skjermen viser valgt dato, en kompakt dagsoppsummering og
varer samlet i én flate per måltid. Varerader viser navn, mengde med lagret
enhet og kcal; trykk åpner redigering, og sveip tilbyr redigering, flytting og
sletting med eksisterende angremulighet. Oppsummeringen er informasjon, ikke
en skjult handling for å nullstille søk eller filter.

Søk åpnes med en knapp i skjermhodet og gjelder valgt dag. Aktivt måltidsfilter
vises med en eksplisitt handling for å vise alle måltider. Ingen søke- eller
filtertreff skilles fra en tom dag, og tilbyr nullstilling uten å endre dato.
Hvert vist måltid har «Legg til» som beholder dato og måltid, samt en meny for
«Lagre som måltid». Generell logging er tilgjengelig fra bunnmenyen.
Den tekstmerkede «Gjenbruk»-menyen samler «Lagre som måltid»,
«Kopier hele dagen fra i går» når tilgjengelig, og «Gå til i dag».
Listeinnhold og angremeldinger skal ha klaring over den vedvarende bunnmenyen.

### Vann på Hjem

Vann vises som nederste rad i samme varme flate som energi og makroer,
skilt med en diskret linje. Når «Vis energi og mål på Hjem» er av, viser
flaten bare vannraden. Valgt dato gjelder hele dagsstatusen; den synlige
etiketten er «Vann», mens VoiceOver inkluderer datoen.

Raden viser antall glass og nøytrale minus-/plussknapper med minst 44 × 44 pt
trykkflate. Blått er begrenset til den dekorative dråpen. Store tekststørrelser
eller liten bredde flytter kontrollene til neste rad. Ingen glassrutenett,
antatt ml-mengde, mål, påminnelser eller målfeiring vises på Hjem.

Pluss lagrer ett glass direkte for valgt dato, også uten nett og konto.
Minus fjerner siste glass uten dialog og er deaktivert ved null. Trykk på
antallet tilbyr fortsatt «Fjern ett glass». Kontroller deaktiveres under
lasting og lagring. Telleren oppdateres først ved vellykket lagring, uten
kvittering eller angreknapp. Feil vises lokalt i raden; lesefeil tilbyr retry.
Næring og vann har uavhengige lastetilstander. Ny dag viser sin egen logg
uten å slette historikken. Telleren animeres kort; redusert bevegelse gir
umiddelbar oppdatering. VoiceOver hopper over dekorasjon og skillelinje.
Vann følger aktiv profileier og inngår i eksport, kontooverføring og sletting.

### Søk

Søk-fanen har et direkte søkefelt og én separat, tekstmerket inngang til
strekkodeskanning. Tastaturet åpnes først når feltet aktiveres. Bunnmenyen skjules
mens søkefeltet redigeres, slik at den ikke dekker treff over tastaturet, og vises
igjen når redigeringen avsluttes. Søk fra Loggfør
bruker samme skjerminnhold i en egen presentasjon med fokusert søkefelt.

«Registrer manuelt» vises som en sekundær knapp i full bredde rett under
Søk og Skann strekkode, før favoritter eller søkeresultater. Knappen er
tilgjengelig i alle søketilstander og bruker samme høyde og avrunding som
handlingsknappene over.

Før søk vises favoritter og inntil seks nylig **loggede** varer. Tomme
seksjoner skjules. Uten favoritter eller historikk vises «Søk etter en matvare
for å komme i gang.», også ved første logging. Råvarer vises først som treff
når brukeren skriver i søkefeltet. Alle produktrader åpner mengdevalg og loggføring. Favoritter og
nylig brukt følger aktiv profileier og oppdateres ved retur fra produktdetaljer
og når skjermen vises igjen.

Navnesøk kombinerer den lokale Matvaretabellen-katalogen og tilgjengelige lagrede
produkter med Open Food Facts for pakkevarer og merkevarer. Lokale treff vises
mens brukeren skriver. Eksternt navnesøk starter først ved «Søk» eller innsending
fra tastaturet. Lokale treff beholdes mens flere produkter hentes og ved nettfeil.
Private produkter fra andre profiler er ikke søkbare.

«Nylig brukt» i Søk viser kompakte produktrader som åpner produktkortet.
Hurtiglogging ligger under «Loggfør igjen» i Loggfør-menyen, med siste
registrerte mengde/enhet og valgt måltid og dato ved hver loggeknapp.
Favoritter og øvrige nylig brukte varer finnes i Søk; «Andre hurtigvalg» vises ikke i Loggfør-arket.
Ved tilgjengelighetstekst ruller søkekontrollene sammen med listen, slik at
kontrollene ikke skyver Nylig brukt utenfor tilgjengelig skjermplass.
Framtidige registreringer brukes ikke som gjenloggingsgrunnlag. Ved like
loggtidspunkter avgjør opprettelsestid og logg-ID rekkefølgen.

Gjenlogging bevarer eksakt g/ml og et kompatibelt porsjonssnapshot. Endret
enhet eller porsjonsgrunnlag krever kontroll i produktkortet. Næringsverdier
beregnes fra gjeldende lokale produktdata; historiske registreringer endres
ikke. Ny registrering og hendelse lagres atomisk uten nettverksoppslag.
Knappene sperres under lagring. Feil beholder varen og lar brukeren prøve
igjen. Bekreftelse vises først etter lokal lagring; Angre bruker den nye
registreringens ID og profil og sletter aldri en annen identisk registrering.
Profil-, dato- eller måltidsbytte under lagring undertrykker en utdatert
bekreftelse; en påbegynt lagring beholder destinasjonen fra trykkøyeblikket.

Resultater viser navn, eventuelt merke og bilde, samt kilde-/enhetskontekst.
Innledende lasting, lesefeil, ingen tidligere produkter, ingen lokale treff og
ingen eksterne treff har ulike tilstander. Feil tilbyr retry uten å tømme søket.
Skanning og fungerende manuell produktregistrering er tilgjengelige alternativer.
Manuell registrering lagrer et brukeroppgitt produkt før mengdevalg og logging.
Et valgfritt produktbilde kan tas med kamera eller velges fra bildebiblioteket
i «Om produktet», med forhåndsvisning, bytte og fjerning før lagring. Bildet
lagres kun lokalt; registrering fungerer uten bilde og ved avvist kameratilgang.
Skjemaet grupperer feltene i «Om produktet» og «Næringsinnhold». Alle dagens
næringsfelt er obligatoriske. «Næringsinnhold per» tilbyr 100 g, 100 ml eller
porsjon/stykk. Porsjon krever navn og størrelse i g/ml; verdier oppgis for én
porsjon og normaliseres til per 100 g/ml ved lagring. Originalverdier og
inntastingsgrunnlag bevares lokalt. Bytte av grunnlag etter inntasting krever
bekreftelse og tømmer næringsfeltene. Kcal eller g er synlig i feltetiketten
også etter inntasting. «Lagre og velg mengde» lagrer
produktet lokalt før mengdevalget åpnes.

### Loggfør

Den sentrale faneknappen heter «Loggfør» og åpner et bunnark uten å endre valgt
hovedfane. Samme ark brukes fra Hjem, bunnmenyen og dagsloggen.
«Registrer manuelt» er alltid synlig og bruker det samme fungerende
produktskjemaet som Søk-fanen, etterfulgt av mengdevalg. Skjemaet åpnes direkte
uten en søkeskjerm som mellomsteg. Avbryt går tilbake til Loggfør-arket;
lagring åpner mengdevalg med valgt dato og måltid bevart. Arket viser alltid «Logg til: [måltid]» og tilbyr:

1. søk etter matvare
2. skann strekkode
3. manuell registrering
4. en todelt velger: «Loggfør igjen» og «Lagrede måltider»

Velgeren ligger under dato og måltidsvalg og viser bare den valgte listen.
«Loggfør igjen» er standard; ved vellykket førstegangslasting velges lagrede
måltider automatisk hvis historikken er tom og maler finnes. Manuelt valg
beholdes mens arket er åpent og overstyres ikke av oppdateringer. Begge valg
har egne laste-, feil- og tomtilstander. Ved stor tekst stables valgene.

Inngangen til «Lagrede måltider» er alltid synlig, også uten maler.
Tomtilstanden forklarer oppretting fra dagsloggens Gjenbruk-meny. Inntil tre
maler vises når «Lagrede måltider» er valgt; «Se alle» åpner hele listen med synlig meny for redigering/sletting. De to innholdstypene har
egne seksjonsoverskrifter, og en måltidsrad viser antall varer i tillegg til
måltidsikon og innholdsoppsummering. En lagret mal åpnes i en forhåndsvisning
med matvarer, mengder, valgt dato og måltidskategori før den loggføres.
Oppretting skjer fra Gjenbruk-menyen i dagsloggen eller menyen til et registrert måltid. Se [lagrede
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

Profilkortet er den faste inngangen til Personlige detaljer; denne lenken
finnes ikke i Innstillinger. Innstillinger samler personvern, visning og
tilbakemelding, data og lagring samt konto. Personopplysninger og forklaringen
om målforslag ligger i Personlige detaljer, mens kalori- og makromål redigeres
i Daglige mål.
Profil viser «Daglige mål» som første rad i menyen, over Favoritter og
Innstillinger. Raden viser lagret kalorimål i kcal per dag, eller «Valgfritt ·
Sett opp mål» når mål mangler. Hele raden åpner Daglige mål; den detaljerte
kalori- og makrooversikten vises på målskjermen.
Personlige detaljer redigeres som et utkast med Avbryt/Lagre. Navn vises i
gruppen «Profil». Fødselsdato, kjønn, høyde, vekt og aktivitetsnivå
samles i kortet «Grunnlag for målforslag», med en kort formålsforklaring før
feltene og «Om opplysningene og målforslag» som utvidbar forklaring etter kortet.
Feltene bruker kompakte rader med verdi til høyre; ved tilgjengelighetsstørrelser
står verdien under feltnavnet. Fødselsdato har en fast rad med «Ikke oppgitt»
som tomtilstand. Dato velges som utkast i datovelgeren og bekreftes
med «Bruk dato». Arket bruker appens bakgrunn, kort og handlingsfarge, med norsk
datovelger og uten handling for å fjerne fødselsdato. Vektens skille fra vekthistorikken forklares under kortet.
Vekt og høyde åpner et ark med skyvbar, horisontal linjal og fast midtmarkør.
Skalaen bruker 0,1 kg (20–300 kg) og 1 cm (80–250 cm). Områdene gjelder bare
linjalen; direkte inntasting bevarer alle gyldige positive verdier og eksisterende
presisjon. Tomme felt starter velgeren på 70 kg eller 170 cm, uten å fylle inn
profilen automatisk. «Bruk verdi» oppdaterer profilutkastet, «Fjern opplysningen»
tømmer feltet, og Avbryt eller lukking forkaster arket. Profilens «Lagre» er
fortsatt eneste lagringshandling. VoiceOver kan justere skalaen med sveip
opp/ned; direkte inntasting er tilgjengelig ved alle tekststørrelser.
Fødselsdato kreves ved lagring av Personlige detaljer; øvrige opplysninger er
valgfrie, og brukeren kan også sette mål selv.
Et valgfritt visningsnavn lagres per profil på enheten, uten synk, og vises i profilkortet
foran eventuelt navn fra kontoen. Eksisterende profiler uten fødselsdato
beholdes, men må velge dato før nye detaljer lagres. Manglende dato og ugyldige tall avvises ved feltet, og lagringsfeil beholder
utkastet på skjermen. «Vekt brukt i målforslag» er beregningsgrunnlag, ikke en vektregistrering.
Oversikt bruker «Registrer vekt» for vekthistorikken.
Endrede opplysninger endrer ikke eksisterende mål automatisk. Målveiviseren
kan åpne Personlige detaljer når beregningsgrunnlaget mangler.

Innstillinger viser lokal lagringsstatus uten gjentatt forklaring når synk ikke
er tilgjengelig. Eksportdetaljer samles under «Hva følger med?», uten egen
forklaring under «Last ned data». I lokal modus har Konto ingen ekstra
lagringsstatusrad; en kort synlig tekst forklarer at konto er valgfritt og at
innlogging foreløpig ikke gir sikkerhetskopi eller synk mellom enheter.

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

### Førstegangsbruk – kontrollert mot kode 2026-10-04

```text
Åpne appen
  → forsøk å gjenopprette eksisterende sesjon
  → opprett lokal profil automatisk når ingen konto er lagret
  → Første måltid: søk med fokus, Skann og Manuelt
  → velg matvare og kontroller mengde, enhet og måltid i produktkortet
  → loggfør lokalt
  → Hjem med bekreftelse og Angre
```

«Gå til Hjem» avslutter førstegangsvisningen uten logging. «Logg inn» er en
sekundær handling. Kort informasjon om lokal lagring og valgfrie konto/mål,
personvernlenke og informasjon om manglende skybackup følger søket. Ved feil
beholdes input slik at brukeren kan prøve igjen. Lokale treff og manuell
registrering fungerer uten nett; eksterne katalogoppslag krever nett.

Ingen introduksjons- eller målveiviser blokkerer første logging. Mål settes
valgfritt under Profil → Daglige mål; oppstart oppretter ikke et skjult mål.
Ved stor tekst stables søkehandlingene vertikalt, og innholdet kan rulles.
Detaljer om fullføring, gjenåpning og kjent konto finnes under
[Første logging](#første-logging-2026-10-02).

Lokal bruk er fullverdig og tidsubegrenset. Konto er et valgfritt valg på
førstegangsvisningen og i Profil. Konto skal ikke omtales som sikkerhetskopi eller
flerenhetssynk før servernedlasting og gjenoppretting er implementert. Hvis en
lokal profil med data logger inn, må brukeren bekrefte før dataene atomisk
knyttes til kontoen. Utlogging skjuler kontodataene på enheten; de blir ikke
synlige for en ny lokal profil.

Målberegninger skal merkes som veiledende. Førstegangsbruk skal ikke love medisinsk
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
oppdaterer ikke personopplysninger. Førstegangsbruk åpner logging direkte; mål settes valgfritt under Profil.

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

## Måltidsrommet

Hjem åpner riktig måltid og dato. Måltidsvelgeren viser Frokost, Lunsj, Middag
og Kveldsmat; «Se hele dagen» tilbyr samlet liste. Datobytte beholder måltidet.
Produktbilder, navn og mengde prioriteres; næring per vare er sekundært.
Trykk eller VoiceOver-handlingen «Rediger» åpner eksisterende redigering; sveiping tilbyr flytting og
sletting med angre. «Legg til mat» beholder valgt måltid og dato.
Samlet næring vises rett under måltidsnavn og antall varer og summerer hele måltidet uavhengig av søk.
Søk gjelder valgt måltid eller hele dagen. Lasting skilles fra tomt måltid og
ingen søketreff. Måltidsmenyen kan lagre alle måltidets varer som en mal.
«Kopier hele dagen fra i går» beholder eksisterende dagsscope.

### Linjalvelger i eldre onboarding – historisk implementasjon

Den eldre målveiviseren (`MatLoggOnboardingFlowView`) er bevart i kode, men
har ingen aktiv inngang i dagens førstegangsflyt. Beskrivelsen nedenfor gjelder
denne veiviseren; aktiv redigering skjer under Profil.

Vekt og høyde bruker samme linjalvelger som Personlige detaljer, med tekst
tilpasset onboarding. «Bruk verdi» oppdaterer bare onboarding-utkastet.
Avbryt beholder tidligere input; tomme felt fylles ikke automatisk med
linjalens startverdi. Direkte inntasting og fjerning er tilgjengelig.
Eksisterende validering avgjør om opplysningene kan brukes i beregningen.

### Første logging (2026-10-02)

Etter forsøk på sesjonsgjenoppretting opprettes lokal profil automatisk ved
første åpning uten lagret konto. Mislykket gjenoppretting av en kjent konto
beholder eksplisitt innloggingsinngang, uten å bytte eier automatisk. Førstegangsvisningen åpner søk med fokus, skanning og manuell
registrering på samme flate. Kort informasjon om lokal lagring, valgfri konto
og mål samt personvernlenke følger søket. Innlogging er sekundær.

Ingen introduksjon, målberegning, personvernside eller oppsummering blokkerer
logging. Måloppsett gjenbruker Profil → Daglige mål. Kamera etterspørres først
etter valgt skanning. Produktkortet beholder mengde, enhet, kilde og måltid.

Bekreftet lokal lagring åpner Hjem med eksisterende kvittering og Angre.
«Gå til Hjem» avslutter også førstegangsvisningen; ellers gjenopptas den ved
neste åpning. Angre starter ikke onboarding på nytt. Tidligere fullført
onboarding bevares. Målet er to skjermer og to trykk pluss tekstinntasting
for lokalt treff med passende foreslått mengde og måltid.

## Antall og porsjonslogging (2026-10-02)

Produktkortet har én mengdevelger med gram/ml og tilgjengelige porsjoner.
Porsjonsvalg viser antallsfelt, −/+, mengde per porsjon, kilde og beregnet total.
Desimalantall er tillatt, og næringsoversikten følger totalen. Første eksplisitte
porsjonsvalg starter på 1; senere enhetsbytter bevarer totalen. Sist brukte
antall gjenbrukes bare når porsjonsgrunnlaget fortsatt matcher.

Logg og redigering viser eksempelvis «2 Polarbrød · 75 g». Historisk grunnlag
bevares ved katalogoppdatering. Basismengde er alltid tilgjengelig. Ugyldig
input deaktiverer lagring, og mislykket redigering beholder utkastet for retry.
Pakkevekt vises som hel pakke; navn alene bestemmer ikke stykkvekt.
Ingen gram/ml-konvertering uten dokumentert grunnlag, og ingen porsjonseditor
inngår i denne versjonen. Produktkortet brukes likt fra skanning og søk.

## Lokal lansering – 3. oktober 2026

Hjem og Profil bruker «Lagret på denne enheten» uavhengig av nettstatus eller
hvilende kø. Ingen ventende opplasting/retry presenteres i lokal modus.
Konto beskrives som innlogging uten skybackup, også ved bekreftet kontokobling.
Første logging viser kort informasjon om datatap og eksport i den scrollbare
listen, før søket er startet. Informasjonen skal ikke låses til bunnen og
fortrenge handlinger ved store tilgjengelighetsstørrelser. Profil → Innstillinger
har samme forklaring og «Eksporter data», med tydelig tekst om manglende import.
Eksisterende tokens, tabbar-clearance og systemdeling beholdes.

### Bearbeidingsgrad på produktkortet (2026-10-03)

OFF-produkter viser en kompakt, trykkbar NOVA-rad før måltidsvalget.
Gruppenavn og kildebasert status vises uten helsescore. Klassifiseringsraden
bruker dempet grønn/rød bakgrunn som beskrevet nedenfor.
Raden åpner et stort, rullbart forklaringsark med produktnavn, status,
tilgjengelig norsk grunnlag, ingredienser og produktlenke. Arket har Lukk
og støtter sveip for lukking. Mengde og måltid bevares. Ukjente markører
vises ikke som tekniske tagger; delvis forståelig grunnlag merkes. Manglende klassifisering og ingredienser beskrives eksplisitt.
Opplysningene følger produktcachen og fungerer offline; klassifiseringen er
gjeldende kataloginformasjon, ikke et historisk snapshot av matloggen.

### Nutri-Score og produktinformasjon (2026-10-03)

Ett produktinformasjonskort samler Nutri-Score og bearbeidingsgrad etter
næringsoversikten per 100 g og før måltidsvalget. Begge rader åpner egne
forklaringsark uten nye nettverkskall. Nutri-Score viser offisiell A–E-grafikk for kjente beregningsversjoner
(2021: original, 2023: «New calculation»). Bildene følger appen og virker
offline. Ved ukjent/manglende versjon vises tekstlig karakter. Kilde og
algoritmeversjon vises i arket; ingen lokal beregning eller poengoversikt.
Manglende karakter vises som «Ikke tilgjengelig». Mengde og måltid bevares.

Grafikken er hentet uendret fra Open Food Facts:
https://static.openfoodfacts.org/images/attributes/dist/nutriscore-{a-e}.svg
og `nutriscore-{a-e}-new-en.svg`. Bruk av offisiell merking følger
https://www.santepubliquefrance.fr/en/nutrition-and-physical-activity/nutri-score
og OFFs veiledning om offisielle assets.

### Forklaring av Nutri-Score (2026-10-03)

Kun Nutri-Score-arket viser kildeoppgitte komponenter og poeng fra samme
2023-beregning som karakteren. Plusspoeng/minuspoeng vises med verdier,
originale enheter og «x av y», uten egne poengberegninger. Estimater og
utelatt proteinbidrag forklares; manglende verdier blir aldri null. Ukjent
versjon eller karakteravvik gir generell forklaring uten beregningsdetaljer.

### Visuelle poengbidrag (2026-10-03)

Nutri-Score-arket viser kompakte komponentrader med navn/verdi, kildepoeng
og segmentbokser. Totalen står ved seksjonstittelen. Lange navn og stor
tilgjengelighetstekst får stablet layout; segmentene brytes etter tilgjengelig
bredde. Plussbidrag bruker grønn nutritionPositiveContribution, minusbidrag rød
nutritionNegativeContribution; farge er aldri eneste
forklaring. VoiceOver leser tekstverdiene, ikke hver boks. Bokser viser bidrag
til Nutri-Score, ikke daglige anbefalinger. Ugyldige/manglende poengtall
eller maksimum over 100 gir ingen segmentillustrasjon.

### Protein som ikke er medregnet

Ved utelatt proteinbidrag vises en proteinrad nederst i plusspoengkortet,
uten poengsegmenter eller nullpoeng. «Teller ikke med i Nutri-Score» åpner
en kort forklaring via infoikon. Mengden vises bare når dokumentert
næringsgrunnlag matcher beregningen og begge gjelder varen som solgt.
Plusspoengtotalen endres ikke.


### Tydeligere språk om ultraprosessering (2026-10-03)

NOVA-raden heter «Er maten ultraprosessert?» og viser kildebasert status:
«Ikke klassifisert som ultraprosessert» for NOVA 1–3, «Klassifisert som
ultraprosessert» for NOVA 4 og «Klassifisering mangler» for ukjent/ugyldig gruppe.
Raden bruker dempet grønn bakgrunn for NOVA 1–3, dempet rød for NOVA 4
og nøytral bakgrunn ved manglende/ugyldig klassifisering. Fargene gjelder bare
klassifiseringsraden, ikke hele produktkortet eller samlet næringskvalitet.
Semantiske tokens støtter lys og mørk modus; fleksibel høyde og full tekst
bevarer tilgjengelighet.
Arket «Ultraprosessert mat» viser produkt, status, gruppeforklaring, avgrensning
mot næringskvalitet, «Hva bygger vurderingen på?», ingredienser, utfellbar
NOVA-forklaring, kilde, hentetidspunkt og produktlenke. Markører knyttes til
aktuell gruppe; ukjent grunnlag gjettes aldri. Gyldig gruppe beholdes selv om
forklarende markører mangler. Åpning krever ingen IO og bevarer loggingstilstand.

### Samlet loggingkort på produktdetaljer (2026-10-03)

Måltid og mengde vises på én kortflate med tydelige deloverskrifter og en
diskret intern skillelinje. Måltidsvalg bruker fire knapper med lik bredde i
et rutenett med to kolonner, valgt måltid i dempet rosa. Dato vises under
Måltid. Mengdevelger, porsjonsgrunnlag, total mengde og «Næringsinnhold for
din mengde» følger under. Full tekst og fleksibel høyde beholdes ved stor
skrift. Den faste «Legg til»-knappen bruker fortsatt valgt måltid.

### Prioritering på produktdetaljer (2026-10-03)

Produktbilde (160 pt), fullt produktnavn og tilgjengelig merke kommer først.
Loggingkortet følger med mengde, næringsinnhold og deretter måltid/dato.
Valgt måltid har både rosa bakgrunn og hake. Produktinformasjon kommer etter
logging og samler utfellbart næringsinnhold per 100 g/ml, Nutri-Score og NOVA
(de to siste når OFF-metadata er tilgjengelige). Kilde, hentetid og
oppdateringshandling følger under. Den faste lagreknappen viser måltid og
total mengde. Eksisterende datagrunnlag, validering og lagring beholdes.

Mengdevelgeren har en ramme rundt valgt porsjon/enhet og nedoverpil.
Antall vises til venstre for en samlet kontroll med minus, tallfelt og pluss.
Ved tilgjengelighetsstørrelser vises etiketten over kontrollgruppen. Generisk
«portion» vises som «Porsjon»; råverdi og lagret porsjonsgrunnlag beholdes.

### Norske feilmeldinger (2026-10-03)

Konto- og lagringsmeldinger bruker norsk tekst fra feiltype/kode eller en
handlingsspesifikk fallback. Rå servertekst og systemfeil vises ikke direkte.
Ukjente feil lover ikke at en flertrinnshandling ble rullet tilbake.
Synkresultater skiller automatisk retry fra behov for oppfølging og omtaler
allerede lagrede hendelser som lokale data. Produksjonssynk aktiveres ikke.
