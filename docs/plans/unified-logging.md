# Samle Søk og Loggfør

Historisk plan: erstattet av avgrensningen 27. november 2026 i docs/design-and-user-flow.md.

Status: godkjent av brukeren og implementert lokalt på `codex/unified-logging`, 17. november 2026. Se verifisering i `docs/testing.md`. Ikke produksjonsutrullet.

## Forbedringsrunde etter skjermbilder – 17. november 2026

Denne delen ble godkjent med «Kjør» og er implementert lokalt. Verifisering føres i `docs/testing.md`.
Den bygger på brukerens tre skjermbilder: den gamle loggføringsmenyen,
den tidligere søkeskjermen og den samlede skjermen på den nye branchen.
Ved gjennomføring erstatter den layoutforslaget nedenfor der beskrivelsene avviker.

### Mål

Behold samlet søk og loggføring, men gi skjermen tydeligere hierarki og mer
plass til matvarene. Hent den kompakte utformingen og de tydelige knappene fra
den gamle loggføringsmenyen. Behold dagens funksjoner, søkeadferd, dato-/måltidskontekst,
gjentatt logging og Angre. Bunnmeny, onboarding, datakilder og lagring inngår ikke
i denne forbedringsrunden.

### Foreslått skjerm

1. **Topp:** «Loggfør» og én «Ferdig»-handling. Bruk eksisterende native toppfelt.
2. **Kontekst:** én kompakt rad med «Til Middag» og «I dag», begge redigerbare.
   En annen dato vises eksplisitt, inkludert år når det er nødvendig. Måltidsmenyen
   og kalenderen åpnes først ved trykk; store permanente felt fjernes.
3. **Primærhandling:** bredt felt med «Søk etter mat» og en kompakt, tekstmerket
   «Skann»-knapp ved siden av, som i bilde 1. Tastaturet åpnes ved trykk i feltet.
4. **Sekundærhandling:** «Registrer manuelt» på egen rad i full bredde.
5. **Gjenbruk:** én samlet velger for «Nylig brukt», «Favoritter» og «Lagrede måltider».
   Felles bakgrunn og markering av valgt del skal vise at dette er alternative lister.
6. **Innhold:** kompakte varerader med navn, sist brukte mengde, pil til mengdevalg
   og en egen rosa «Loggfør»-knapp for direkte gjenbruk. VoiceOver-navnet inkluderer
   varen og mengden. Varer som krever gjennomgang viser «Kontroller mengde».

Et uferdig utkast vises kompakt under de primære handlingene. Det skal fortsatt
kunne gjenopptas eller forkastes, uten å skyve søk under første skjermbilde ved
vanlig tekststørrelse. Unngå dobbel overskrift der valgt gjenbruksliste allerede
forklarer innholdet.

### Søk og tastatur

- Fjern den store rosa søkefirkanten fra den samlede skjermen.
- Lokale treff vises fortsatt mens brukeren skriver. Tastaturets «Søk» utfører
  dagens eksplisitte eksterne søk; det skal ikke starte automatisk under skriving.
- Når tekst er skrevet inn, vises også en kompakt teksthandling «Søk etter produkter»
  i søkeområdet. Dermed er eksternt søk tilgjengelig med skjult tastatur og
  hjelpemidler. Bruk dagens laste-/deaktiveringsregler og forklaring ved nettfeil.
- Søkeresultater erstatter gjenbruksvelgeren og listen mens søket har innhold.
  Tømming gjenoppretter tidligere valgt liste. Behold valgt dato og måltid.
- Behold «Skjul tastatur» som separat handling under redigering, slik at den
  ikke kan forveksles med «Ferdig» som avslutter hele loggføringsøkten.

### Layout, tilstander og tilgjengelighet

Bruk semantiske farger, typografi, knappestiler og spacing fra designsystemet.
Reduser avstandene mellom kontekst, søk og gjenbruk; ikke krymp trykkflatene.
Undersøk både egne padding-verdier og standardmargene fra dagens grupperte List
før de justeres. Behold List hvis den kan gi ønsket resultat; unngå unødvendig
utskifting av liste- og presentasjonsstrukturen.

Ved stor tekst eller smal bredde stables kontekstraden, søk/Skann og gjenbruksvalgene.
Velgeren beholder felles innramming også når den stables. Ingen etiketter skal
deles midt i ord, skaleres ned eller klippes. Alle handlinger har minst 44 pt
trykkflate, tydelige VoiceOver-navn og valgt-status som ikke bare uttrykkes med
farge. Toppfelt, tastatur og Angre-kvittering skal ikke dekke aktive kontroller.

Behold separate tom-, laste- og feiltilstander for hver liste. Lokal logging
skal fungere uten nett. Kvitteringen skal fortsatt vises inne i arket etter
lagring; feil ved lagring skal bevare input uten å vise suksess.

### Arbeidsrekkefølge og berørte filer

1. Juster først kontekst og søkeområdet i `MatLogg/Views/Home/FoodSearchView.swift`.
   Hold endringen avgrenset til samlet Loggfør; andre brukere av FoodSearchView
   beholder sin flyt. Bruk eksisterende AppState-kontekst og søke-ViewModel.
2. Samle gjenbruksvelgeren og gi nylige varer tydelige knapper i samme fil.
   Gjenbruk stil og mønster fra `MatLogg/Views/Home/QuickLogSheet.swift` uten å
   kopiere inn en ny implementasjon av lagring eller gjenlogging.
3. Juster mellomrom og eventuelt utkastbannerets presentasjon. Flytkoordineringen
   i LoggingFlowView/LoggingFlowViewModel endres bare hvis layouten krever det.
4. Inspiser skjermen på samme skjermbredde og tekststørrelse som brukerens bilde 3.
   Sammenlign start, tastatur, treff, gjenbruk og kvittering med syntetiske QA-data.
5. Oppdater berørte UI-tester og normative designbeskrivelser når utformingen
   implementeres. Gjennomgå diffen mot arkitekturprinsippene før ferdigmelding.

### Ferdigkriterier og minste verifisering

- Ved vanlig tekststørrelse vises kontekst, søk, Skann, manuell registrering,
  gjenbruksvelger og minst to komplette nylige varer på skjermbredden i bilde 3,
  uten å rulle, når utkast- og feilmeldinger ikke vises.
- Med tastaturet åpent kan et lokalt treff nås; eksternt søk kan startes både fra
  tastaturet og den synlige teksthandlingen. Ingen automatisk ekstern søking.
- Stor tekst gir lesbare kontroller som kan nås ved rulling, uten horisontal
  klipping. Dato og måltid kan endres og er forståelige for VoiceOver.
- Direkte gjenlogging og åpning av mengdevalg er to separate handlinger.
  To registreringer på rad, Angre og retur til valgt dag fungerer som før.
- Kjør de berørte UI-scenariene for samlet logging/Angre, manuell retur,
  tidligere dato, gjenbruksvalg og stor tekst. Oppdater forventningene til ny
  plassering av søkehandlingen uten å fjerne funksjonskontrollene.
- Kjør FoodSearchTests/QuickLogTests bare dersom tilhørende state eller logikk
  faktisk endres. Backendtester og full testpakke kreves ikke for ren layout.
- Visuell inspeksjon av vanlig og største tekststørrelse er et eget ferdigkrav;
  grønne UI-tester alene er ikke tilstrekkelig for denne forbedringen.

Største risiko er at komprimeringen skjuler valgt loggkontekst, gjør knapper
for små eller flytter bort den eksplisitte eksterne søkehandlingen. Kontroller
disse punktene før videre polering. Behold ett stort ark i denne runden;
endring av arkets høyde eller navigasjonsmodell vurderes separat ved behov.

## Mål og avgrensning

Én inngang for å finne og loggføre mat, uten dagens mellomsteg fra Loggfør til Søk. Hjem, Utvikling og Profil beholdes. Søk tas ut som egen fane, men funksjonene beholdes i Loggfør. Backend, lagringsformat, næringsberegninger og synkpolicy inngår ikke i endringen.

## Ønsket brukerflyt

- Loggfør åpner et stort ark med egen NavigationStack. Tastaturet åpnes først ved trykk i søkefeltet.
- Øverst vises Loggfør og Ferdig, deretter redigerbar dato og måltid, søkefelt og handlingene Skann strekkode og Registrer manuelt.
- Uten søketekst vises Nylig brukt, med synlige valg for Favoritter og Lagrede måltider. Nylig brukt er standard. Tomme valg beholdes med forklaring og relevante neste handlinger.
- Med søketekst vises søkeresultater i stedet for gjenbrukslisten. Tømming av søket gjenoppretter valgt liste. Skanning og manuell registrering er fortsatt tilgjengelig.
- Valg av matvare åpner eksisterende produkt-/mengdeflyt. Å se på en vare krever ikke logging.
- Legg til på Hjem bruker valgt dato og måltidet på kortet. Den generelle knappen bruker valgt dag og eksisterende måltidsforslag. Konteksten beholdes ved søk, skanning, manuell registrering, tilbake og feil.
- Etter vellykket lagring lukkes bare produkt-/mengdeflyten. Loggfør forblir åpen for neste vare; søk og listevalg beholdes. Lokal bekreftelse med Angre vises inne i arket. Ferdig lukker arket og viser oppdatert underliggende fane.
- Lagrede måltider følger samme prinsipp: forhåndsvisning før logging, deretter tilbake til samlet skjerm. Bevar eksisterende sikker angreoperasjon.
- Avbryt fra skanning eller manuell registrering går tilbake til samlet skjerm. Eksisterende gjenoppretting av uferdig manuell registrering beholdes. Kontroller at sveip for å lukke ikke omgår utkastbeskyttelsen.

## Implementeringsrekkefølge

### 1. Samlet inngang og presentasjonsstate

Bruk LoggingFlowView i `MatLogg/Views/Home/QuickLogSheet.swift` som inngang. Flytt den til egen feature-fil hvis det gjør ansvaret tydeligere. Erstatt QuickLogSheet som startskjerm med samlet søk og gjenbruk. Gjenbruk FoodSearchView/FoodSearchViewModel, QuickLogViewModel og eksisterende repositories; ikke bygg en ny søkemotor.

Dato, måltid, valgt gjenbruksliste, destinasjon og fullføringsflyt eies av en liten feature-ViewModel der eksisterende modeller ikke dekker ansvaret. Opprett den ved flytens rot med injiserte avhengigheter. Views utfører ikke IO. Unngå å kopiere asynkrone data mellom konkurrerende modeller. Profilbytte skal avbryte eller forkaste gamle resultater og tømme gammel kontekst.

### 2. Søk og gjenbruk i én innholdsflate

Tilpass `MatLogg/Views/Home/FoodSearchView.swift` for den samlede skjermen: ingen automatisk fokus, kontekst over søk og tre gjenbruksvalg. Gjenbruk eksisterende visning og handlinger for favoritter, nylig brukt og lagrede måltider. Bevar lokale/katalogbaserte søk, kildeinformasjon, mengdevalg og separate laste-, tom- og feiltilstander. Frakoblet katalogoppslag skal ikke blokkere tilgjengelig lokal logging.

### 3. Fullføring, bekreftelse og tilbake

Gjennomgå alle dismiss-/completion-stier i LoggingFlowView, QuickLogSheet og tilknyttede produkt-, skanne-, manuelle og lagrede måltidsflyter. I dag lukker flere av disse hele Loggfør-arket etter lagring. Endre dem samlet slik at hver lagring gir én bekreftelse og én oppdatering, uten dobbeltlogging eller toast skjult bak arket. Gjenbruk eksisterende lagring og angrehandlinger. Ved feil beholdes input og kontekst for nytt forsøk.

### 4. Bunnmeny og gamle søkeinnganger

Oppdater `MatLogg/DesignSystem/Components/MatLoggTabBar.swift` til Hjem, Loggfør, Utvikling og Profil i denne rekkefølgen, med Loggfør som fremhevet handling. Fire elementer krever ikke en kunstig sentrert plassering. Lag eksplisitt layout for stor tekst; dagens indeksbaserte fire-faners layout kan ikke gjenbrukes uendret.

Oppdater `MatLogg/Views/Home/HomeView.swift`, AppTab i `MatLogg/App/AppState.swift` og berørt navigasjonskoordinering. Søk etter alle `.search`-ruter før fjerning: innganger som fortsatt trengs skal åpne samlet Loggfør, eventuelt med søkefokus etter eksplisitt søkehandling. Behold eksisterende råvaresøk og onboardingflyter der de har egne behov. Fjern bare kode som er dokumentert ubenyttet av denne endringen.

### 5. Dokumentasjon og egen review

Når retningen implementeres, oppdater `docs/product-brief.md`, `docs/design-and-user-flow.md`, relevante bunnmeny-/søkeavsnitt i `docs/design-system.md`, berørte beskrivelser i `docs/specs/` og `docs/current-state.md`. Før beslutningen kort i `docs/decisions.md` og oppdater berørte testinstruksjoner i `docs/testing.md`.

Gjennomgå diffen mot `docs/architecture-principles.md`: View → ViewModel → Repository, ingen ny featurelogikk i AppState, uendret atomisk lokal lagring og kø, bevart eierisolasjon og testbare IO-grenser.

## Målrettet verifisering og ferdigkriterier

- ViewModel-tester: riktig dato/måltid fra begge innganger, liste-/søkestate ved tilbake og fullføring, feil med bevart input og forkasting av resultater etter profilbytte. Utvid eksisterende suiter der ansvaret allerede ligger.
- Kjør berørte eksisterende tester i FoodSearchTests, FoodSearchLoadingTests og QuickLogTests, samt tester for den nye flytkoordineringen. Bruk målrettede kommandoer fra `docs/testing.md`.
- Oppdater UI-testen som forventer en Søk-fane til å bruke Loggfør. Tilpass testene for manuell avbryt/retur og tidligere dato til den nye startskjermen; ikke fjern de funksjonelle kontrollene.
- Målrettede UI-scenarier: to varer etter hverandre uten å åpne Loggfør på nytt; logging på tidligere dato fra måltidskort; favoritt og lagret måltid; manuell avbryt og vellykket logging; lagringsfeil uten kvittering; angre som fjerner bare riktig nye registrering.
- Visuell kontroll i tilgjengelig QA-simulator: normal og stor tekst, VoiceOver-rekkefølge, tastatur, fullhøydeark, lukking og retur til hver fane. Minst 44 pt trykkflater og semantiske tokens. Ark har egen bunnklaring; gjenværende faneskjermer bruker matLoggTabBarScrollClearance().
- Kontroller strekkodeskanning på fysisk enhet hvis kamera ikke kan verifiseres i simulator. Rapporter dette som verifiseringshull frem til utført.

Ferdig når alle loggmetoder nås direkte fra den samlede inngangen, Søk ikke lenger finnes som egen fane, gjentatt logging og angre fungerer, kontekst bevares, og målrettede kontroller består. Full testpakke, backenddeploy og produksjonsutrulling inngår ikke i denne planen.

## Risiko og tilbakeføring

Størst risiko er feil dismiss-nivå i nestede presentasjoner, mistet dato/måltid og doble eller skjulte bekreftelser. Endre og verifiser den samlede flyten før den separate Søk-fanen fjernes. Hold endringen avgrenset slik at navigasjonsendringen kan reverseres uten datamigrasjon.

Skills: product-review, product-design, ios-swiftui og qa-release. Planleggingen bygget på kode og dokumentasjon. Etter implementering er målrettede enhets-/UI-tester kjørt og skjermbilder gjennomgått; resultater og gjenværende kontroll på fysisk enhet føres i `docs/testing.md`.
