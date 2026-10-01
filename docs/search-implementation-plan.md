# Implementeringsplan: Søk

## Mål og scope

Søk skal la brukeren finne, gjenbruke og loggføre en matvare med få steg.
Dette fullfører eksisterende MVP: råvarer, merkevarer, favoritter, nylig brukt,
skanning og manuell registrering. Ingen nye datakilder, filtre, serverendringer,
migrasjoner eller analyseinnsamling. Branchen er `codex/search-experience`,
opprettet fra `main`.

## Implementering

1. Erstatt inngangsmenyen med et direkte tekstfelt i Søk-fanen. Behold én
   tekstmerket skannehandling. Gjenbruk samme innhold i søkepresentasjonen fra
   Loggfør; bare denne presentasjonen fokuserer tekstfeltet automatisk.
2. Vis favoritter, inntil seks nylig loggede varer og åtte råvareforslag før
   brukeren søker. Produktet åpnes for eksplisitt mengde, dato og måltid.
   Oppdater biblioteket ved retur, etter produktdetaljer og i forgrunnen.
3. Last lokale katalog- og profileide produkter via repository. Filtrer og ranger
   lokalt mens brukeren skriver. Søk i navn og merke med eksisterende matching.
   Open Food Facts kalles bare ved søkeknapp eller tastaturets søkehandling.
4. Behold lokale treff under nettlasting og feil. Vis egen innledende lasting,
   lesefeil med retry, ingen lokale treff og ingen eksterne treff. Tilby manuell
   produktregistrering og skanning også når søket ikke gir treff.
5. La egen `FoodSearchViewModel` eie bibliotek, resultater, lasting, feil og
   produktåpning. Sett repository sammen ved app-roten og injiser ved IO-grensen.
   Hver presentasjon eier egen ViewModel og egen søketilstand.
6. Bruk eksisterende produktregistrerings- og loggføringsflyt. Nye katalogvarer
   caches før åpning uten synkhendelse. Manuelle produkter lagres med eksisterende
   atomiske domeneskriving/synkkø. Bevar næringsverdier, kilde og g/ml-grunnlag.
7. Oppdater flytspesifikasjon og beslutningslogg. Verifiser søkelogikk, eierskap,
   asynkrone kontekstskifter og UI-flyten med målrettede tester.

## Akseptansekriterier

- Søk-fanen har direkte søk uten et mellomliggende ark eller dupliserte snarveier.
- Ingen tastatur åpnes automatisk på fanen; Loggfør-søket fokuserer feltet.
- Bunnmenyen skjules under søkeinntasting og kommer tilbake når redigeringen avsluttes.
- Favoritter og nylig brukt viser reelle produkter for aktiv lokal profil/konto.
- Treff er knapper som åpner mengdevalg; fullført logging gir eksisterende kvittering.
- Skriving utløser ingen nettforespørsel. Lokale treff er brukbare under nettlasting.
- Nettfeil fjerner ikke lokale treff. Retry bevarer søket.
- Gamle svar forkastes også ved gjentatt søk på samme tekst og ved profilbytte.
- Lokalt navnesøk inkluderer delte katalogvarer og bare aktiv eiers private varer.
- Ingen treff gir en fungerende manuell registrering og tilgjengelig skanning.
- Rader bevarer navn, merke, bilde/fallback, datakilde og korrekt måleenhet.
- Stor tekst får vertikale, tekstmerkede søkehandlinger uten dekorative handlingsikoner.
  Bunnmenyens etiketter skaleres opptil ordinær XXXL; innholdet følger full tekststørrelse.
  Rader kan bryte tekst, VoiceOver får
  samlet radtekst og handlingshint, og fanens liste bruker bunnmenyklaring.

## Verifisering og arkitektur

Målrettet `FoodSearchTests`, eksisterende `ProductSearchTests` og UI-tester for
søk → produkt → logging/gjenbruk, manuell fallback og stor tekst. Testresultater
rapporteres i leveransen; full testpakke og produksjonsutrulling inngår ikke.

Avhengighetsretningen er View → feature-ViewModel → repository → lokal store/API.
Views gjør ingen direkte IO. Asynkrone publiseringer kontrollerer request-ID og
profileier. Endringen tilfører en lokal lesing, uten å endre transaksjonsgrenser,
synkformat eller produksjonsflagg. Manuell lagring bruker eksisterende atomiske
skriving; næringsberegning og selve matloggen følger eksisterende flyt.
