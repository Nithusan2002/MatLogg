# Lagrede måltider

## Brukerbehov og scope

Brukeren kan lagre et allerede registrert enkeltmåltid som en navngitt mal og
senere loggføre alle matvarene samlet. Dette er rask gjenbruk, ikke oppskrifter,
måltidsplanlegging eller automatiske anbefalinger.

Første versjon omfatter:

- «Lagre som måltid» fra en måltidsgruppe i Logg
- navn, matvarer, eksakte mengder, næringssnapshot, kilde og rekkefølge
- ett valgfritt lokalt måltidsbilde fra iOS-bildevelgeren
- «Lagrede måltider» øverst i Loggfør-arket
- forhåndsvisning og mengdejustering før logging
- logging til valgt dato og måltidskategori, også når måltidet har innhold fra før
- endring av navn/mengder, fjerning av varer og sletting av malen
- kompakt lokal kvittering og atomisk angre

Det er ikke støtte for å bygge en ny mal fra et tomt lerret, legge til nye varer
i en eksisterende mal, mapper, deling, porsjonsskalering eller
oppskriftstekst i denne versjonen.

## Flyt og design

I Logg åpner menyen ved en måltidsoverskrift «Lagre som måltid». Brukeren gir
malen et navn og kontrollerer innholdet. Den opprinnelige loggen endres ikke.
Brukeren kan velge ett bilde, se forhåndsvisning, bytte eller fjerne det både
ved oppretting og redigering. Bilde er valgfritt, og avbryt lagrer ingen endringer.
Lagring er deaktivert mens bildet lastes. Feil beholder et eventuelt tidligere
bilde og viser en melding. Listen og forhåndsvisningen viser lagret bilde.

Bildet er bare lokalt: det lastes ikke opp, synkroniseres ikke og følger ikke
nye logginnslag ved bruk av malen. iOS-bildevelgeren krever ikke generell
bibliotektilgang. Bilder begrenses til 1200 piksler på lengste side og 2 MB JPEG;
original fotometadata fjernes. Importer over 30 MB avvises. Et iCloud-bilde
kan kreve nett før import, men allerede importerte bilder fungerer offline.

Loggfør-arket viser inntil tre lagrede måltider før favoritter og nylig brukte
matvarer. «Se alle» åpner administrasjon. Trykk på en mal åpner alltid en
forhåndsvisning med matvarer, mengder, valgt dato og måltidskategori før den
loggføres. Ingen mal loggføres automatisk.

Kilde vises bare når brukerens kildevalg er aktivert. Eksisterende semantiske
farger, typografi, kort og
knapper brukes. Handlinger har minst 44 pt trykkflate og tekst kan brytes ved
Dynamic Type.

Forhåndsvisningen bruker en kompakt destinasjonsrad som kan utvides ved behov.
Hver vare viser navn, valgfri kilde og en samlet mengdekontroll med `g`.
Primærhandlingen ligger fast nederst og angir hvor mange varer som loggføres,
slik at den forblir tilgjengelig også når måltidet har mange varer.

## Data og arkitektur

`SavedMealsViewModel` bruker `SavedMealRepository` og `FoodLogRepository`,
injisert ved app-roten. `SavedMeal` er et eget brukereid aggregat; bruk av en
mal oppretter nye, selvstendige `FoodLog`-verdier. Endring eller sletting av en
mal påvirker aldri historiske logger.

Hvert element bevarer produkt-ID, produktnavn, numerisk mengde, enhet (`g` eller
`ml`), de eksakte lagrede næringsverdiene og ernæringskilden som brukeren
godkjente. Mengdeendring
skalerer dette snapshotet og henter ikke stille nyere produktverdier.

Valgfri `localImageData` lagres i måltidets eksisterende JSON-rad, slik at bilde,
mal og synkhendelse skrives atomisk. Eldre rader dekodes med manglende bilde.
`SavedMealSyncPayload` utelater bildefeltet; ingen server- eller kontraktsendring
kreves. Sletting av malen eller profildata fjerner også bildet. Lokal eksport
inkluderer JPEG-data som base64.

Lokalt SQLite-skjema v2 legger til `saved_meals`. Skriving av malen og
`saved_meal.upsert` skjer i én transaksjon. Sletting og `saved_meal.delete`
gjør det samme. Når malen brukes, gjenbrukes den atomiske batchskrivingen for
individuelle `log.upsert`-hendelser. Backend lagrer mal og elementer atomisk og
autoriserer mot eier fra tokenet.

Synken er fortsatt bare opplasting av hendelser. Serverlagring innebærer derfor
ikke at malen kan lastes ned på en annen enhet ennå, og dette loves ikke i UI.
Produksjonssynk forblir deaktivert.

## Akseptansekriterier

- En mal inneholder 1–50 varer, navn på 1–80 tegn og mengder over 0 og høyst
  10 000 g.
- Manglende lokalt produktgrunnlag stopper hele handlingen; varer utelates
  aldri stille.
- Dobbelttrykk kan ikke opprette doble maler eller logger.
- Alle logger fra én bruk lagres, eller ingen lagres.
- Angre sletter bare loggene opprettet av siste bruk av malen.
- Kontoendring fjerner presentasjonstilstand og kvittering for forrige bruker.
- Oppretting, redigering, bruk og sletting fungerer uten nett.
- Eksport og kontosletting omfatter lagrede måltider.
