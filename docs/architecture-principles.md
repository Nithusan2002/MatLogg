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

### SwiftUI-state og asynkrone resultater

- `@State` brukes bare til kortlivet, view-lokal presentasjonstilstand. Resultater
  fra repository/service, domeneobjekter som lastes asynkront, validering og
  flertrinnsflyter skal eies av en `@MainActor`-ViewModel.
- `@StateObject` brukes når View-et oppretter og eier objektets levetid.
  `@ObservedObject` brukes for eksplisitt injiserte, observerbare objekter, og
  `@EnvironmentObject` reserveres for faktisk appomfattende observerbar state.
  Ikke bruk observable wrappers som servicelokator for tjenester uten publisert UI-state.
- Når flere asynkrone forespørsler kan overlappe, skal ViewModel kansellere den
  gamle oppgaven eller kontrollere en stabil request-ID/valgt kontekst før et
  resultat publiseres. Et eldre svar skal aldri kunne overskrive nyere brukervalg.
- Verdier som kommer inn gjennom en View-initializer skal ikke kopieres til
  `@State` uten at det er en bevisst redigeringssnapshot. Husk at state kun
  initialiseres første gang SwiftUI oppretter den aktuelle view-identiteten.

### SwiftUI-rendering og ytelse

- `body` og beregnede properties som leses av `body` skal være fri for database-,
  filsystem- og nettverksarbeid. ViewModels laster data på forhånd og leverer
  ferdige presentasjonsverdier; lister skal ikke gjøre ett repository-oppslag per rad.
- Sortering, gruppering, filtrering, formattering og domeneberegninger skal ikke
  gjentas flere ganger i samme renderpass. Beregn én gang når input endres, eller
  bind resultatet til en lokal verdi dersom arbeidet er lite og rent visuelt.
- State som endres raskt, som tekstfelt, dra-bevegelser og animasjonsverdier, skal
  eies så langt nede i view-hierarkiet som mulig. Et tastetrykk i én kontroll skal
  ikke invalidisere diagrammer, bilder eller hele faneskjermer uten behov.
- Observer bare state viewet faktisk viser. Store `EnvironmentObject`-avhengigheter
  skal deles opp eller oversettes til smale verdi-inputs når hyppige, irrelevante
  publiseringer ellers invalidiserer store view-trær.
- `ForEach` skal bruke en stabil, unik domene-ID. Ikke bruk indeks, visningstekst
  eller `\.self` når verdier kan flyttes, oversettes eller forekomme flere ganger.
  `.id()` er et identitetsverktøy, ikke en generell ytelsesoptimalisering, og skal
  ikke brukes for å tvinge rekonstruksjon uten en eksplisitt state-reset.
- `Equatable`/`.equatable()` brukes bare på rene, målte render-hotspots med komplette
  verdi-inputs. IO og overflødig avledet arbeid skal fjernes før diffing optimaliseres.
- Bruk `FormatStyle` eller gjenbrukbare formattere fremfor å opprette formatterobjekter
  per rad eller renderpass.

### Feilhåndtering ved runtime-grenser

- Ikke force-unwrap konfigurasjon, URL-er, filsystemresultater, dekodet input eller
  andre verdier som kan variere ved runtime. Bruk `guard` og en typet feil, eller
  en eksplisitt dokumentert fallback som bevarer local-first-adferd.
- Nye eller endrede runtime-grenser skal testes med ugyldig konfigurasjon og
  manglende data. Tester skal verifisere kontrollert feil, ikke prosesskrasj.

## Lokal lesing og feiltilstander

Dette er krav til nye og endrede grenser. Eldre avvik er teknisk gjeld,
ikke godkjente mønstre. Kravene betyr ikke at alle eksisterende leseflyter
allerede er utbedret; faktisk status føres i current-state og utbedringsplanen.

- Skill vellykket tom samling, manglende valgfri rad og mislykket lesing.
  Domene-lesinger formidler feil gjennom LocalStore/service → repository →
  ViewModel eller eksport, normalt med `throws` eller et eksplisitt typet utfall.
- Standardimplementasjoner og kompatibilitetslag skal bevare denne kontrakten.
  En throwing-metode som faller tilbake til en feilskjulende lesing er ikke
  en feilformidlende grense. Ikke innfør nye kall til eldre slike metoder.
- Kontroller SQLite prepare, bindings og stepping. En fler-radslesing er først
  vellykket når den avsluttes med SQLITE_DONE. Dekodingsfeil i nødvendige
  domenerader skal ikke gi et tilsynelatende komplett delresultat eller lavere
  ernæringssummer. Bevar originaldata; ikke slett eller reset som automatisk recovery.
- `try?`, `?? []`, `?? 0`, `nil` eller `.empty` skal ikke skjule feil i nødvendige
  datakilder. Eksport skal feile kontrollert hvis en nødvendig kilde ikke kan
  leses; manglende næringsdata erstattes ikke med gjetninger.
- Best-effort tillates for gjenoppbyggbar cache bare når alternativ kilde,
  feilutfall og brukeradferd er dokumentert og testet. Cachepolicy skal ikke
  brukes for å skjule feil i brukerdata eller brukerbekreftet matching.
- ViewModel eier lasting, feil og retry. Ved oppdateringsfeil kan sist lastede
  data beholdes for samme profil og kontekst, med tydelig feilstatus. Ved
  profil-/datobytte tømmes gammel kontekst. Request-ID/kansellering skal beskytte
  både suksess- og feilpublisering mot utdaterte svar.
- Diagnostikk skal være nyttig uten domeneinnhold, personopplysninger eller
  rå SQL-/dekodingsdetaljer i brukerrettet tekst.

## Ansvarsdeling og kontrollert refaktorering

- Del store filer etter sammenhengende ansvar og konkrete endrings-/testbehov,
  ikke etter en vilkårlig linjegrense. Skill mekanisk flytting fra feilretting
  i reviewbare endringer og verifiser at flyttingen bevarer adferden.
- LocalStore eier SQLite-tilkobling, seriell kø, migrasjoner og transaksjoner.
  En filoppdeling skal ikke eksponere databasepekeren bredt, opprette parallelle
  lagre eller splitte atomisk domene-/synk-/Helse-outbox-skriving. Vurder
  reentrancy/deadlock, statement-opprydding og rollback ved berørte endringer.
- Ny serverfunksjonalitet legges i Supabase. Før legacy avvikles, avklar aktive
  klienter/drift, delte transporttyper, tester og deploy-/CI-avhengigheter.
  Behold cutoverkravene i backend/README til en eksplisitt beslutning endrer dem;
  ukjent drift er ikke bevis på at en tjeneste er ubrukt.

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
- For endrede lesegrenser: test gyldig tomt resultat, kildefeil og korrupt rad,
  samt delresultat, retry, kontekstbytte og utdaterte svar der det er relevant.
  Kontroller regresjonen før retting når praktisk; ikke svekk assertions.
- Knytt testbevis til kodecommit, eventuelle lokale endringer og testmiljø.
  Skill kompilering fra utførte tester og automatisk kontroll fra manuell QA.
  Bruk syntetiske data og separat QA-identitet på fysisk enhet. Hold rå logger,
  resultatpakker og store QA-artifacts utenfor repoet; dokumenter kort resultat
  og nødvendige referanser. Lokal sammenslåing er ikke en releasegodkjenning.
- Oppdater kontrakt og begge sider samtidig når synkformatet endres.
- Dokumenter større avvik og varige valg i `docs/decisions.md`.
- Rapporter alltid hva som ble verifisert, og hva som ikke kunne verifiseres.
