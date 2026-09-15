# Arkitekturprinsipper

Dette dokumentet er normativt for nye endringer i MatLogg. Eksisterende kode
som avviker, behandles som teknisk gjeld; avvik skal ikke kopieres videre.

## Pragmatisk MVVM i iOS-klienten

- SwiftUI-views viser tilstand og videresender brukerintensjoner. De skal ikke
  eie domenelogikk, databasekall, nettverkskall eller synkronisering.
- En feature-ViewModel eier presentasjonstilstand, validering og koordinering av
  brukerhandlinger. ViewModels skal være `@MainActor` når de publiserer UI-state.
- Repositories er grensen mellom ViewModels og data. De skjuler om data kommer
  fra SQLite, nettverk, cache eller flere kilder.
- Services implementerer avgrenset infrastruktur som lagring, API, auth og synk.
  Domeneregler skal ikke flyttes til en generell service eller `AppState`.
- `AppState` er kun appomfattende koordinering: navigasjon, valgt kontekst,
  session/synkstatus og globale feil.
- Avhengigheter settes sammen ved app-roten og injiseres gjennom små protokoller
  der det gir testbarhet. Unngå nye skjulte singletons i feature-kode.
- Små, rent visuelle komponenter trenger ikke egen ViewModel. MVVM brukes ved
  reelt state-, domene- eller IO-ansvar, ikke som mekanisk filoppdeling.

Tillatt avhengighetsretning:

`View → ViewModel → Repository → Service/local store/API`

Ikke tillatt: `View → LocalStore/API`, repository som importerer UI, eller
domenelogikk som permanent plasseres i `AppState`.

## Local-first og synk

- En brukerhandling lagres lokalt før nettverksforsøk og skal fungere offline.
- Domeneskriving og innsetting i synkkø skjer atomisk i samme SQLite-transaksjon.
- Hver hendelse har stabil `eventId`, canonical type og eksplisitt
  `schemaVersion`. Gjeldende format er [synkkontrakt v1](sync-contract-v1.md).
- Retry skal være tapsfri. Backend dedupliserer på `eventId`, og inboxregistrering
  og domeneskriving skjer i samme databasetransaksjon.
- Klient og backend endres sammen ved kontraktsendringer. Bakoverkompatibilitet,
  utrullekkefølge, delvis batch-feil, klokkeavvik og flere enheter vurderes
  eksplisitt.
- Produksjonsflagget holdes av til kontrakt-, retry-, idempotens-, eierskaps- og
  integrasjonstester er grønne.

## API, sikkerhet og dataeierskap

- All ekstern input valideres ved API-grensen med stabile, maskinlesbare feil.
- Identitet hentes fra verifisert token. `userId` fra klientpayload skal aldri
  brukes som autoritativ identitet.
- Lesing, oppdatering og sletting autoriseres mot ressursens faktiske eier.
- Ernæringsdata beholder kilde og måleenhet gjennom hele flyten. Manglende
  næringsverdier skal ikke gjettes.
- Hemmeligheter, tokens, persondata og ekte produksjonsdata skal ikke lagres i
  repo, logger eller testfixtures.

## Endringskrav

- Hold løsningen innen avtalt scope og bruk eksisterende abstractions før nye
  lag introduseres.
- Nye IO-avhengigheter skal kunne erstattes i tester.
- Test minst berørt happy path og risikorelevante feilmoduser.
- Oppdater kontrakt og begge sider samtidig når synkformatet endres.
- Dokumenter større avvik og varige valg i `docs/decisions.md`.
- Rapporter alltid hva som ble verifisert, og hva som ikke kunne verifiseres.
