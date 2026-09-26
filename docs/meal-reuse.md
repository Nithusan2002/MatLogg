# Gjenbruk av gårsdagens måltid

## Scope og brukerbehov

Brukeren skal kunne registrere et kjent måltid uten å søke opp hver matvare
på nytt. Første versjon er en avgrenset utvidelse av rask logging: gjenbruk av
gårsdagens måltid fra Hjem. Den omfatter ikke måltidsplanlegging, målbaserte
matforslag, automatisk rutinegjenkjenning eller helgemodus.

## Flyt og tilstander

- Et tomt måltidskort på Hjem kan vise «Frokosten fra i går?» (tilsvarende for
  øvrige måltider), med alle matvarer og mengder. Når kalorier er synlige,
  vises også lagret kcal for hvert innslag; Trygg modus fjerner kcal fullstendig.
  Det foreslås ikke matvarer
  som mangler produktinformasjon lokalt.
- «Loggfør» lagrer måltidet på dagens dato i samme måltidskategori.
- «Juster» åpner et utkast med opprinnelig mengdeenhet (`g` eller `ml`),
  produktkilder når kildevisning er aktivert, og mulighet til å fjerne matvarer.
  Avbryt endrer ingen logger.
- «Ikke nå» skjuler forslaget for denne dagen i gjeldende appøkt. Scrolling
  avviser ikke forslaget. Allerede registrerte måltider får ikke forslag.
- Uten historikk vises den ordinære tomtilstanden og «Legg til».
- Ingen nettforbindelse er nødvendig. Feil beholder utkastet, forklares ved
  handlingen og lar brukeren forsøke lagring igjen.
- Etter lagring vises en kvittering med «Angre». Angre fjerner bare innslagene
  fra siste gjenbruk. En ny gjenbruk erstatter kvitteringen; eldre innslag kan
  fortsatt redigeres og slettes i den ordinære loggen.
- Bytte av bruker eller dag ugyldiggjør gamle forslag og utkast. Angre er
  tilgjengelig i gjeldende appøkt/dagskontekst.

## Data og arkitektur

`MealReuseViewModel` bruker `FoodLogRepository`, injisert ved app-roten.
Historikk behandles lokalt, uten ny analyseinnsamling eller ekstern AI.
Viewet har ansvar for presentasjon og videresending av handlinger.

Uendrede mengder beholder loggens lagrede næringsverdier. Endrede mengder
skalerer dette historiske grunnlaget, ikke en mulig nyere produktverdi.
Modellen lagrer numerisk mengde og enheten `g` eller `ml`, og refererer til
produktet for kildeinformasjon. Den har ikke et separat historisk kildesnapshot
eller den opprinnelige porsjonsetiketten. Eldre data uten enhet tolkes som gram.

Alle måltidets innslag og deres canonical `log.upsert`-hendelser lagres i én
lokal SQLite-transaksjon. Angre bruker tilsvarende atomisk sletting med
`log.delete`. Hendelsesformat og backend-kontrakt endres ikke. Serveren mottar
fortsatt individuelle hendelser; lokal atomisitet innebærer ikke en ny
servertransaksjon på tvers av hele måltidet. Produksjonssynk forblir deaktivert.

## Akseptansekriterier og tilgjengelighet

- Bare gårsdagens innslag for innlogget bruker og riktig måltid foreslås.
- Ingen lagring skjer før et eksplisitt trykk; dobbelttrykk gir ikke duplikater.
- Ugyldig eller tom mengde, tomt utkast og foreldet dagskontekst kan ikke lagres.
- Lagringsfeil gir verken et halvt måltid eller delvis tilhørende synkkø.
- Angre berører ikke gårsdagens data eller andre registreringer i dag.
- Forslaget viser lagret kcal når kalorivisning er aktivert. Trygg modus fjerner
  kcal og mål fra både synlig UI og VoiceOver. Editor viser ikke kalorier.
- Semantiske farger/typografi, eksisterende knapper og kort brukes. Tekst kan
  bryte over flere linjer, og handlinger har minst 44 pt trykkflate. Ingen ny
  animasjon, lyd eller haptikk er nødvendig for å forstå bekreftelsen.

## Liten brukertest før bredere prioritering

Bruk syntetiske måltider og la deltakerne både gjenbruke et uendret måltid og
endre én mengde/fjerne én matvare. Bytt rekkefølge mellom vanlig logging og
gjenbruk mellom deltakerne. Noter tid til korrekt lagring, feilregistreringer,
behov for hjelp og om «Angre» blir forstått. Test også manglende historikk og
Trygg modus. Dette er en testplan; ingen brukertest er gjennomført ennå.

## Verifisering 2026-09-21

- `xcodebuild test -project MatLogg.xcodeproj -scheme MatLogg -destination
  'platform=iOS Simulator,id=11D56C8D-12E5-43A6-B327-C19E3086940E'
  -derivedDataPath /tmp/MatLoggMealReuseBuild -only-testing:MatLoggTests
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO`: **61 tester bestod**
  på en isolert iPhone 17 Pro / iOS 26.5-simulator.
- 13 nye ViewModel-tester dekker filtrering på eier/dato/måltid, manglende
  produkter, næringssnapshot, justering, ugyldige mengder, lagringsfeil/retry,
  dobbelttrykk, eksisterende registreringer, angre/retry, midnatt, kontobytte,
  foreldede asynkrone svar og tall utenfor lagringens grense.
- Fire nye SQLite-tester dekker canonical hendelser, atomisk rollback når
  den andre hendelsen feiler under lagring/sletting, retry og tomme batcher.
- Siste simulatorbygg med `xcodebuild build` og `git diff --check` bestod.
- Et tidlig skjermbilde viste forslaget i måltidskortet. Endelig interaktiv
  kontroll, VoiceOver og store tekststørrelser er **ikke verifisert**:
  skjermverktøyet feilet ved tilkobling, og simulatorens skjermdump ble ikke
  fullført. Dette erstatter ikke brukertesten over.
- Backend er uendret og ble ikke testet på nytt. Produksjonssynk er fortsatt av.

Arkitekturkontroll: View → ViewModel → Repository → LocalStore, injeksjon ved
app-roten, local-first, én lokal transaksjon per handling, eierskapskontroll
og tester uten nett/database i ViewModel er ivaretatt. Ingen planlagte avvik
fra arkitekturprinsippene. Klar for videre lokal prøving; ingen
produksjonsgodkjenning er gitt.
