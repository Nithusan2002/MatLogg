# MatLogg – produktbrief

Dette dokumentet beskriver produktets hensikt og avgrensning. Det er normativt
for produktretning, men ikke en oversikt over hva som allerede er implementert.
Se [gjeldende prosjektstatus](current-state.md) for faktisk status og
[MVP-spesifikasjonen](specs/01-mvp-scope.md) for detaljert scope.

## Produktløfte

MatLogg skal gjøre det raskt og rolig å registrere mat, forstå dagens inntak og
følge egen utvikling uten at brukeren er avhengig av nett.

Den viktigste gjentatte brukerjobben er:

> Jeg skal registrere det jeg har spist, med minst mulig friksjon og med tydelig
> informasjon om mengde, næringsverdi og datakilde.

## Problemet

Matlogging blir lett tidkrevende, moraliserende eller avhengig av uoversiktlige
datakilder. Norske brukere trenger en enkel arbeidsflyt med relevante matvarer,
forståelige enheter og kontroll over sensitive mål- og vektdata.

## Målgruppe

Første målgruppe er norske iPhone-brukere som ønsker enkel oversikt over mat,
energi og makronæringsstoffer. Produktet skal fungere både for brukere som har
konkrete mål og for brukere som ønsker en roligere logg uten synlige kalorier
eller progresjonsmål.

MatLogg er et logg- og oversiktsverktøy. Det skal ikke presenteres som medisinsk
behandling, diagnostikk eller individuell ernæringsfaglig rådgivning.

## Produktprinsipper

1. **Rask logging først.** Søk, skanning og gjenbruk av nylige eller lagrede
   matvarer skal være lett tilgjengelig.
2. **Local-first.** En gyldig registrering lagres lokalt med en gang. Manglende
   nett skal ikke hindre logging eller fremstilles som tap av data.
3. **Rolig og ikke-dømmende.** Språk og visualisering skal informere uten skam,
   alarmisme, press eller overdrevne helseløfter.
4. **Kilde og enhet bevares.** Dokumenterte, beregnede og brukeroppgitte verdier
   skal kunne skilles. Manglende næringsverdier skal ikke gjettes.
5. **Brukeren styrer detaljnivået.** Safe Mode, kildevisning og målstatus skal
   være sammenhengende valg, ikke kosmetiske brytere.
6. **Personvern som standard.** Mat-, mål- og vektdata behandles som sensitive,
   samles inn med et tydelig formål og deles ikke unødvendig.

## Kjerneopplevelse

MatLogg har fem hovedinnganger:

1. **Hjem** – dagens status og måltider.
2. **Søk** – råvarer, produkter, favoritter og nylig brukt.
3. **Loggfør** – sentral handling for søk, skanning og manuell registrering.
4. **Fremgang** – valgfri vektregistrering og historikk.
5. **Profil** – personlige detaljer, mål, trygghet, personvern, konto og synk.

Den sentrale kjerneflyten er:

```text
Åpne appen
  → velg eller behold foreslått måltid
  → søk, skann eller velg en kjent matvare
  → kontroller mengde, enhet, næringsverdi og kilde
  → lagre lokalt
  → få en kort kvittering og velg neste handling
```

## MVP

MVP-en prioriterer:

- e-postbasert innlogging og onboarding
- dagsoversikt og fire måltider
- logging via søk, strekkode og manuell registrering
- norske råvarer fra Matvaretabellen og produktoppslag fra Open Food Facts
- eksakt mengde, måltid og dato
- favoritter, nylig brukt og skannehistorikk
- lokal lagring og versjonert synkkø
- mål, valgfri vektregistrering og Safe Mode
- synlig datakilde når brukeren ønsker det
- eksport og sletting av brukerdata

Detaljert scope og prioritet finnes i
[MVP-spesifikasjonen](specs/01-mvp-scope.md). Ved konflikt med implementert
status gjelder [current-state.md](current-state.md) og kodebasen.

## Ikke del av første produksjonsklare leveranse

Følgende skal ikke innføres uten en ny produktbeslutning:

- sosial feed, venner, konkurranser eller gamification
- medisinske anbefalinger eller automatiske behandlingsråd
- automatisk utfylling av manglende næringsverdier
- Apple Health, treningsklokker eller andre helseintegrasjoner
- annonser, abonnement eller andre inntektsflater
- omfattende oppskrifts- og måltidsplanlegging
- produksjonssynk før kontrakt-, retry-, idempotens-, eierskaps- og
  integrasjonstestene er grønne

## Tidlige suksessindikatorer

Før faste KPI-mål settes skal pilotmåling avklares med personvern og faktisk
samtykke. Nyttige produktsignaler er:

- brukeren fullfører sin første logging uten hjelp
- tiden fra åpnet loggføring til lokal lagring er kort
- søk eller skanning fører til en gyldig registrering
- brukeren kan fortsette å logge uten nett
- brukeren forstår hvilken kilde og måleenhet verdiene kommer fra
- Safe Mode skjuler kalorier og mål konsekvent
- feil kan rettes uten at allerede utfylt mengde eller måltid går tapt

## Viktigste risikoer

- feil eller ufullstendige næringsdata svekker tillit
- mål- og progresjonsvisning oppleves som dømmende eller helseskadelig
- eldre spesifikasjoner skaper avvik mellom forventning og implementasjon
- synk aktiveres før eierskap, retry og idempotens er tilstrekkelig testet
- valgfri analyse eller krasjrapportering tas i bruk uten gyldig samtykke og
  oppdatert juridisk tekst
