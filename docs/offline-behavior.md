# Offline-adferd og synkstatus

Dato: 2026-09-27  
Status: normativ produkt- og UX-definisjon; produksjonssynk er fortsatt deaktivert

MatLogg er local-first. Nettverk skal aldri være nødvendig for å registrere,
se, redigere eller slette brukerens egne data på enheten. Lokal lagring er
fullført arbeid; synk er en etterfølgende kopi til backend, ikke en forutsetning
for at handlingen skal lykkes.

## Dette skal fungere uten nett

For en bruker som allerede har en gyldig lokal sesjon og har åpnet appen minst
én gang, skal følgende fungere rent lokalt:

- vise dagsoversikt, historikk og tidligere lagrede næringssnapshots
- opprette, redigere, flytte og slette matlogger
- logge fra lokale råvarer, tidligere brukte produkter, favoritter, lokal
  katalogcache og lagrede måltider
- opprette brukeroppgitte produkter med dokumenterte verdier; manglende
  næringsdata skal ikke gjettes
- opprette og endre favoritter, lagrede måltider, daglige mål og vektlogger
- bruke Trygg modus, visningsvalg og andre lokalt lagrede preferanser
- angre en lokal logging og eksportere data som allerede finnes på enheten

Hver domeneskriving og tilhørende synkhendelse skal skrives atomisk i samme
SQLite-transaksjon. Hvis den lokale skrivingen feiler, er handlingen ikke
lagret; input beholdes og brukeren får «Prøv igjen». Hvis skrivingen lykkes,
skal senere nettverksfeil aldri rulle tilbake eller skjule de lokale dataene.

## Dette krever nett

- første gangs registrering, innlogging og gjenoppretting av en utløpt sesjon
- nye oppslag i eksterne produktkataloger og oppdatering av gammel katalogcache
- serverbasert deling, kontosletting og andre handlinger som eksplisitt endrer
  servertilstand utenfor synkkøen
- henting av endringer fra en annen enhet; synkkontrakt v1 støtter bare opplasting

Ved eksternt søk eller skanning uten nett skal lokale treff fortsatt vises og
merkes som lagrede treff. Manglende lokalt treff er ikke det samme som at
produktet ikke finnes; brukeren tilbys manuelt produkt eller nytt forsøk senere.

## Når forbindelsen kommer tilbake

1. Synkkøen vekkes når appen starter eller blir aktiv, og mens appen kjører når
   nettverksmonitoren oppdager at forbindelsen er tilbake. iOS garanterer ikke
   kjøring i bakgrunnen akkurat idet nettet kommer tilbake.
2. Bare hendelser med `ownerUserId` lik den aktive autentiserte brukeren kan
   velges for opplasting. Brukerbytte eller utlogging avbryter planlagte retries.
3. Eldre hendelser uten verifiserbar eierbinding beholdes lokalt i karantene.
   De sendes aldri, og Innstillinger viser bare et generisk antall uten innhold.
4. Ventende hendelser sendes i rekkefølge i batcher på maksimalt 50.
5. Backend dedupliserer på stabil `eventId`; et timeout-retry skal derfor ikke
   duplisere en domeneskriving.
6. Bekreftede hendelser markeres `acked`. Midlertidige feil forblir `pending`
   og prøves igjen med lagret, avgrenset backoff.
7. Permanent avvisning eller fem mislykkede automatiske forsøk flytter
   hendelsen til `deadLetter`. Dataene beholdes lokalt, og Innstillinger tilbyr
   et eksplisitt manuelt nytt forsøk.
8. Delvis batch-suksess behandles per hendelse; bekreftede hendelser sendes ikke
   på nytt, og avviste hendelser skjules ikke bak en generell suksessmelding.

Automatisk synk skal ikke blokkere logging eller presenteres som en modal
prosess. En manuell synkhandling kan vise feil, men må fortsatt forklare at
dataene er lagret på enheten.

## Konfliktregler

### Gjeldende synkkontrakt v1

V1 er kun opplasting. Den håndterer leveringskonflikter, ikke flerenhetskonflikter:

- samme `eventId` er samme handling og anvendes høyst én gang
- to forskjellige entitets-ID-er bevares som to registreringer; backend skal
  ikke gjette at like produkter, mengder eller klokkeslett er duplikater
- en hendelse som bryter validering, eierskap eller støttet schema/type avvises
  og beholdes lokalt som en synkfeil
- klienten skal aldri overskrive lokale data med en serverversjon, fordi v1
  ikke har nedlasting eller en kanonisk serverrespons for domenedata

Det betyr at endringer fra flere enheter ikke konvergerer i dagens MVP. Appen
skal ikke påstå «Alt synkronisert» som om enheten også har mottatt andre
enheters endringer; statusen betyr bare at denne enhetens kø er bekreftet.

### Krav før toveis synk kan innføres

Toveis synk krever en ny, versjonert kontrakt med serverrevisjon per aggregat,
stabil enhets-ID og eksplisitte tombstones for sletting. Klienten sender hvilken
serverrevisjon endringen bygger på. Ved revisjonskonflikt skal serveren bevare
begge kandidatene til klienten har håndtert svaret; den skal ikke bruke
klientklokke eller skjult «siste skriv vinner».

Minimumsregler for en senere kontrakt:

- forskjellige logg- eller vekt-ID-er bevares som separate registreringer
- samtidig redigering av samme ID krever at brukeren velger lokal eller
  serverversjon, med begge verdier og tidspunkt synlig
- sletting av samme ID vinner over en samtidig redigering, men tombstone
  beholdes lenge nok til å hindre at en frakoblet enhet gjenoppretter raden
- favoritt legg til/fjern avgjøres per produkt-ID; fjerning vinner ved samtidig
  konflikt
- mål og lagrede måltider behandles som hele aggregater og krever eksplisitt
  valg ved revisjonskonflikt

Produksjonssynk skal forbli deaktivert til disse reglene enten er irrelevante
fordi produktet er eksplisitt én-enhets, eller er implementert og testet i både
klient og backend.

## Synlig status for brukeren

Status skal uttrykkes med tekst og ikon, aldri bare farge:

| Tilstand | Primær tekst | Plassering og handling |
| --- | --- | --- |
| Lokal lagring pågår | «Lagrer på enheten …» | Kun ved handlingen; blokker gjentatt lagring. |
| Lagret, venter | «Lagret på enheten – venter på synk» | Kort bekreftelse etter lagring og samlet, diskret status på Hjem. |
| Offline med kø | «Du er offline. X endringer er lagret på enheten og venter på synk.» | Status på Hjem; trykk åpner Data og synk. |
| Synk pågår | «Synkroniserer X endringer …» | Data og synk; ikke modal. |
| Denne enhetens kø er tom | «Alle endringer fra denne enheten er synkronisert» | Data og synk med tidspunkt for siste bekreftelse. |
| Automatisk retry | «X endringer er lagret på enheten og prøves igjen når appen kan synkronisere» | Data og synk; vis neste planlagte forsøk når kjent. |
| Krever handling | «X endringer er lagret på enheten, men kunne ikke synkroniseres» | Data og synk med «Forsøk synk på nytt». |
| Backend-synk deaktivert | «Lagret bare på denne enheten» | Data og synk; ikke bruk «venter» uten å forklare at synk ikke er tilgjengelig. |

En vellykket lokal handling skal aldri vises som mislykket bare fordi synk
venter. Vedvarende status vises bare når det finnes ventende eller feilede
hendelser; en kort suksessmelding kan vises når en tidligere kø blir tom.

VoiceOver skal lese både lokal trygghet og videre status, for eksempel:
«Tre endringer er lagret på enheten og venter på synk». Dynamisk tekst skal
kunne brytes over flere linjer uten at status eller retry-handling forsvinner.

## Akseptansekriterier

- Flymodus under lagring gir umiddelbart synlige, persistente data etter
  omstart, med samme stabile event-ID i køen.
- Nett tilbake starter automatisk synk uten å blokkere ny logging.
- Timeout og gjentatt levering oppretter ikke duplikater på backend.
- Delvis batch-feil og permanent avvisning gir korrekte antall og tydelig
  manuelt neste steg, mens lokale data fortsatt vises.
- Hjem og Innstillinger skiller mellom lokal lagring, ventende synk,
  synkfeil og bekreftet tom enhetskø.
- Ingen tekst lover flerenhetskonsistens før toveis synk er implementert.
