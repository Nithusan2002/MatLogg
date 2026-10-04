# Norske og forståelige feilmeldinger

Dato: 2026-10-03. Status: gjennomført i kode for konto, lokal lagring og brukerrettede
synkresultater. Målrettet verifisering og visuell kontroll rapporteres separat.

## Mål og avgrensning

Brukeren skal forstå hva som gikk galt, om handlingen ble fullført og hva
som kan gjøres videre. Rå servertekst, databasefeil og engelske systemmeldinger
skal ikke vises direkte. Kildeverdier, produktnavn og historisk datagrunnlag
skal bevares. Planen endrer presentasjon, ikke autentisering, tilgang,
transaksjoner, retry-regler eller produksjonsflagg.

## Bekreftede funn

- `AuthViewModel.swift` viser `localizedDescription` direkte eller som tillegg
  ved innlogging, kontokobling og sletting.
- `LogViewModel.swift`, `ProductViewModel.swift` og `HealthProfileViewModel.swift`
  legger tekniske feilbeskrivelser til brukerrettede lagringsmeldinger.
- `APIService.APIError` videresender nettverks-/servertekst og bruker blant annet
  «sync-events» og «payload». Den aktive synktransporten er `SupabaseService`;
  serverfeilkoder må kartlegges der, ikke bare i legacy-transporten.
- `SyncEngine.swift` bruker rå feiltekst i resultater og avvisninger. Avklar
  hvilke felt som er diagnostikk og hvilke som faktisk når brukergrensesnittet.
- Porsjonsvisning er oversatt, og tall-/datovisning på produktkortet er rettet.
  Andre skjermers datoer og tall bør inngå i avsluttende språkkontroll.

## Prioritert gjennomføring

| Trinn | Arbeid | Ferdigkriterium |
| --- | --- | --- |
| 1 | Kartlegg feiltyper, stabile Supabase-koder, visningssteder og handlingens lagringsstatus. Les arkitekturprinsipper og relevante kontrakter. | Alle meldinger i berørte flyter har kjent opphav, fallback og dokumentert statusgrunnlag. |
| 2 | Lag en liten, ren og testbar oversetter til norsk presentasjon, basert på feiltype/kode og handlingskontekst. | Ingen matching av engelsk feiltekst; ukjente feil får trygg norsk fallback. Views utfører ingen feiltolkning eller IO. |
| 3 | Bruk oversetteren ved innlogging og kontohandlinger. | Ugyldige opplysninger, nettfeil, utløpt økt og ukjent feil har korrekte meldinger og neste handling. Ingen endring i auth-/tilgangsadferd. |
| 4 | Oppdater lokal logging, redigering, favoritter og mål/vekt. | Meldingen skiller mislykket lokal skriving fra feil etter vellykket skriving; input beholdes, og retry gir ikke dobbeltregistrering. |
| 5 | Oppdater synkresultater og brukerrettede avvisninger. | Lokal lagring omtales som fullført bare når det er bekreftet. Midlertidig feil skilles fra permanent avvisning. Produksjonssynk forblir deaktivert. |
| 6 | Kontroller øvrige visninger for råverdier, engelsk tekst, datoer og tall. | Standard UI-tekst er norsk; konkrete kilde-/produktbetegnelser og måleenheter bevares. |

## Meldingsprinsipper og eksempler

Eksemplene må knyttes til bekreftet feiltype og faktisk status før bruk:

- Ugyldige innloggingsopplysninger: «E-post eller passord er feil. Prøv igjen.»
- Nettverksfeil ved innlogging: «Kunne ikke koble til. Sjekk nettforbindelsen og prøv igjen.»
- Utløpt økt: «Økten din er utløpt. Logg inn på nytt.»
- Mislykket lokal skriving: «Kunne ikke lagre maten. Prøv igjen.»
- Bekreftet lokal lagring med midlertidig synkfeil, når synk er tilgjengelig:
  «Lagret på denne enheten. Synkroniseringen prøves igjen senere.»
- Ukjent feil: En norsk melding knyttet til handlingen, uten rå feildetaljer
  eller antakelser om nett, datatap eller lagring.

Behold nyttige valideringsmeldinger. Vis meldingen nær relevant felt/handling,
med fleksibel høyde, VoiceOver og tekstbasert neste steg. Ikke skjul eierskaps-
eller dataintegritetsfeil bak en misvisende nettverksmelding.

## Arkitektur og diagnostikk

ViewModels leverer presentasjonsmeldinger. En liten delt oversetter kan
ligge i presentasjonslaget og bruke eksisterende typede feil; services og
repositories beholder sine tekniske feil og transaksjonsgrenser. AppState
skal ikke bli hjem for feilklassifisering.

Diagnostikk skal bruke nødvendige feilkoder og anonymisert kontekst.
Ikke flytt rå meldinger til logger ukritisk: de kan inneholde persondata,
SQL eller serverdetaljer. Ingen nye tokens, helseopplysninger eller
produksjonsdata skal logges. Eksisterende diagnostikk vurderes separat fra UI.

## Verifisering og leveranser

- Målrettede tester for kjente feilkoder, ukjent kode, nettfeil og norsk fallback.
  Bruk engelsk og sensitiv eksempeltekst for å verifisere at råtekst ikke vises.
- Kontroller feil før lokal commit, etter lokal commit og ved retry med fakes.
  Test faktisk bevaring av input og antall lagrede hendelser, ikke bare tekst.
- Utvid relevante tester, blant annet `AuthServiceTests`, `APIServiceTests`
  og `SyncRetryTests`, samt ViewModel-tester der presentasjonen endres.
- Simulator-build etter Swift-endringer. Målrettet UI-kontroll av innlogging,
  logging og feilvisning med stor tekst og VoiceOver; ingen full suite uten grunn.
- Oppdater relevante UX-spesifikasjoner. Backendkontroller kreves bare dersom
  serverkode/kontrakt faktisk endres. Auth-/tilgangsendringer eller utrulling
  krever egen avklaring etter AGENTS.md.

Bruk `product-design`, `ios-swiftui`, `nutrition-privacy` og `qa-release`.
Bruk også `backend-api` for auth/API og `offline-sync` for synkresultater.
Lever i små endringer: først oversetter og innlogging, deretter lokal lagring,
til slutt synk og avsluttende språkkontroll. Hver endring skal ha egne
målrettede kontroller før neste trinn.

## Gjennomført

`UserFacingError` gir norsk presentasjon fra Supabase-authkoder, nettfeiltyper
og eksisterende API-feiltyper, med trygg fallback. ViewModels for konto,
logging, produkt, helseprofil og onboarding viser ikke rå feiltekst.
API-feilbeskrivelser videresender ikke server-/nettverkstekst. Synkresultater
skiller automatisk retry fra endringer som trenger oppfølging, uten endring
i eventlagring, backoff eller auth. Demofeil har norsk fallback.

Oppfølging: visuell kontroll av feiltilstander og større tekst, samt separat
vurdering av eksisterende tekniske synkdiagnoser lagret lokalt. Denne
endringen legger ikke til diagnostikk eller produksjonssynk.
