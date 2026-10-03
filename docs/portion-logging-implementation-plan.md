# Implementeringsplan: logging med antall og porsjoner

Dato: 2026-10-02. Status: implementert lokalt; målrettet automatisert QA grønn. Ingen deploy.

## Avklart scope

Brukeren skal kunne logge eksempelvis to Polarbrød uten å regne gram selv.
Første versjon bruker eksisterende porsjonsdata. Opprettelse av egne porsjoner
inngår ikke. Antall og valgt porsjon skal bevares i loggen og ved redigering.

Løsningen gjelder produktkortet, uansett om varen åpnes fra skanning, søk,
favoritter eller nylig brukt. Den skal fungere uten nett for lagrede produkter.
Ingen automatisk gjenkjenning av stykkvekt fra bilder eller produktkategori.
Ingen tetthetsberegning eller omregning mellom gram og milliliter.
Ingen toveis synk, ny konfliktstrategi eller produksjonsutrulling.

## Utgangspunkt ved planlegging

- `ServingOption` i `MatLogg/App/Models.swift` har ID, label, mengde, enhet,
  kilde og standardforslag. Feltet `grams` kan også representere milliliter.
- `APIService.buildServingOptions` bruker OFF-porsjonsdata, men lager også
  heuristiske forslag fra pakkevekt og produktnavn samt en «100 g/ml»-knapp.
  Disse kan ikke ukritisk behandles som dokumentert stykkvekt.
- `ProductDetailView` setter bare mengden når en porsjonsknapp trykkes.
  Mengdetekst, validering og næringsberegning ligger delvis i viewet.
- `ProductDetailViewModel` håndterer foreløpig produktoppdatering.
- `FoodLog` bevarer total mengde, enhet og næringsverdier, men ikke antall
  eller porsjonsgrunnlag. Redigering skalerer lagrede næringsverdier.
- `LocalStore.saveLogs` skriver logg og `log.upsert` atomisk. Loggpayloaden
  og Supabase-skjemaet inneholder ikke porsjonsmetadata.
- Synk er en opplastingskontrakt; nedlasting er ikke implementert.
- Mange berørte filer har pågående lokale endringer. Implementasjonen må
  ta utgangspunkt i disse og bevare annet arbeid.

## 1. Porsjonsgrunnlag og normalisering

Utvid eksisterende `ServingOption` med bakoverkompatible, strukturerte felt
for kort visningsnavn og type: porsjon, stykk, hel pakke eller basismengde.
Bevar rå label, numerisk grunnlag, enhet og kilde. Ikke utled antall fra label
ved hver UI-rendering. Bruk stabile identiteter ved gjentatt katalogimport.

Regler i OFF-adapteren:

- Dokumentert porsjonsmengde med samme enhet som næringsgrunnlaget kan brukes.
- Navn som «Polarbrød» eller «bar» er ikke i seg selv dokumentasjon på stykkvekt.
  Ved tvetydig tekst brukes «porsjon» og originalteksten som forklaring.
- Total pakkevekt kan tilbys som «hel pakke», ikke automatisk som ett stykk.
- «100 g/ml» behandles som basismengde, ikke tellbar porsjon.
- Avledede halvporsjoner trenger ikke egne valg; brukeren kan skrive 0,5.
- Ukjent, ugyldig, ikke-endelig eller inkompatibel mengde gir ingen tellbar
  porsjon. Direkte gram/ml er fortsatt tilgjengelig.
- Eldre heuristiske cacheverdier brukes ikke som dokumenterte porsjoner.
  Normaliser lokalt når grunnlaget finnes; ellers bruk basismengde til et
  nytt oppslag er tilgjengelig. Unngå tvungen nettavhengighet.

Ferdig når adaptertester skiller porsjon, pakke og basismengde og avviser
inkompatible data. Polarbrød-eksempelet fungerer dersom lagret grunnlag
faktisk dokumenterer 37,5 g per Polarbrød.

## 2. Felles mengdemodell og UI

Lag en liten, ren domenemodell for mengdevalg: direkte mengde eller porsjon
med antall. Total = antall × porsjonsmengde. Bruk Double i nye beregninger;
konverter eksplisitt ved eksisterende Float-grenser. Avrund bare ved visning.
Gjenbruk `NutritionCalculator` fremfor en ny næringsberegningsmotor.

Flytt mengdestate, parsing, validering og avledede næringsverdier ut av
`ProductDetailView` til feature-ViewModel. Gjenbruk samme mengdelogikk i en
avgrenset redigerings-ViewModel. Repository-grensen beholdes; avhengigheter
injiseres ved app-roten. Ingen ny domenelogikk i `AppState`.

Mengdekortet bruker eksisterende kort, farger og typografi:

1. Velg gram/ml eller en tilgjengelig porsjon.
2. Ved porsjon: numerisk antallsfelt med −/+; én valgt porsjon starter på 1.
3. Vis «37,5 g per Polarbrød» og «Totalt: 75 g» for antall 2.
4. Oppdater næringsoversikten fra den beregnede totalen.

Foreslått atferd:

- Behold eksisterende initialvalg/sist brukte mengde der det er gyldig;
  lagret antall gjenbrukes bare når porsjonsgrunnlaget fortsatt matcher.
- Første eksplisitte valg av porsjon starter på 1. Ved bytte til gram/ml
  bevares totalen. Ved bytte fra direkte mengde til porsjon konverteres
  totalen til antall. Bytte mellom porsjoner bevarer totalen.
- Tillat desimalantall med norsk komma og punktum. −/+ endrer med 1;
  hvis minus gir null eller negativt antall, er knappen deaktivert.
- Ugyldig/ufullstendig tekst beholdes mens brukeren skriver, men lagring
  deaktiveres. Krev positive, endelige tall og total ≤ 10 000 g/ml.
- Ikke åpne tastaturet automatisk. Gi konkrete feilmeldinger på norsk.
- Produktoppdatering skal ikke stille endre valgt porsjonsgrunnlag.
  Behold aktivt snapshot og forklar endringen; bruk nye porsjonsdata etter
  eksplisitt nytt valg. Endret næringsenhet følger eksisterende beskyttelse.
- VoiceOver leser antall, porsjon, grunnlag og total. Kontroller har minst
  44 punkters trykkflate og fungerer med stor tekst og tastatur.
- Bevar `matLoggTabBarScrollClearance()` der skjermen ligger under bunnmenyen.

## 3. Lagre antall og historisk porsjonsgrunnlag

Legg et valgfritt `portionSelection`-snapshot til `FoodLog`:

| Felt | Formål |
| --- | --- |
| `servingId` | Referanse til valgt porsjon, ikke eneste historiske grunnlag |
| `label` | Navnet som skal vises ved gjenåpning |
| `count` | Uavrundet antall |
| `amountPerServing` | Mengden som gjaldt da loggen ble lagret |
| `unit` | g eller ml, samme som loggens enhet |
| `source` | Proveniens for porsjonsgrunnlaget |
| `kind` | Porsjon, stykk eller hel pakke |

Total mengde og lagrede næringsverdier beholdes som eksisterende beregnings-
og summeringsgrunnlag. Valider at snapshot og total samsvarer innen en
definert Float/Double-toleranse; skriv ikke motstridende verdier.

- Gamle logger uten snapshot åpnes som gram/ml. Ingen historisk gjetting.
- Produktoppdatering eller sletting av en porsjon endrer ikke gammel logg.
- Redigering av antall bruker lagret porsjonsgrunnlag og skalerer lagret
  næringssnapshot, slik eksisterende redigering allerede gjør.
- Bytte til direkte mengde fjerner porsjonsmetadata ved lagring.
- Bare måltidsendring bevarer porsjonsmetadata uendret.
- Feilet lagring beholder redigeringsstate og tillater trygg retry.

Utvid `LogViewModel.logFood/updateLog` og relevante modeller/presentasjoner:
loggrad, hjemmets måltidsinnhold og kvittering viser f.eks. «2 Polarbrød · 75 g».
Utvid brukerdataeksporten med snapshot. Gjennomgå alle `FoodLog`-kopieringer,
sletting/angre og måltidsgjenbruk slik at metadata ikke mistes.

Ved kopiering av logg beholdes snapshot. Ved skalering skaleres også antall.
Hvis lagrede måltider tar utgangspunkt i logger, utvid `SavedMealItem` og dens
lagring/synk med samme valgfrie snapshot. Gjenbruk eksisterende flyter og
grenser; ingen ny måltidsfunksjon eller porsjonseditor.

## 4. Lokal lagring og Supabase-kontrakt

Utvid Codable og JSON-lagringen additivt; manglende felt er nil. En lokal
SQL-migrasjon er bare nødvendig hvis nye indekserte kolonner kreves.
Logg/snapshot og køhendelse skal fortsatt skrives i samme transaksjon.

Utvid `LogSyncPayload`, Supabase Zod-skjema, SQL/RPC og relevante
`saved_meal.upsert`-felt samlet. Bruk versjonert, ikke-destruktiv SQL-migrasjon
for valgfritt snapshot, med format- og konsistensvalidering. Behold tokenbasert
eierskap, RLS, deduplisering og dagens konfliktregler.

Anbefalt kontrakt: additivt valgfritt felt i v1, fordi eksisterende payloads
fortsatt er gyldige. Dokumenter dette eksplisitt og verifiser det med tester.
Hvis kompatibilitetskontrollen viser behov for v2, må klient og server støtte
overgangen før klienten sender det nye formatet; ikke bare øk versjonstallet.

Rekkefølge i test/staging: database → Edge Function → klient. Gamle køevents
sendes uendret med stabile event-ID-er. Eldre payloads må ikke utilsiktet
slette lagret snapshot ved måltidsendring; definer og test semantikken for
manglende felt kontra eksplisitt null. Gammel klient som endrer totalmengde
må ikke etterlate et snapshot som motsier ny total.

Gammel server kan forkaste ukjente Zod-felt; ny klient skal derfor ikke sende
porsjonsmetadata før serverstøtte er bekreftet i målmiljøet. Backend-synk i
produksjon forblir deaktivert. Nedlasting mellom enheter loves ikke.

## 5. Målrettet verifisering

| Område | Nødvendig dekning |
| --- | --- |
| Mengde | 2 × 37,5 = 75; 0,5 porsjon; komma/punktum; enhetsbytte; øvre grense; NaN/overflow; ingen skjult avrunding |
| OFF-import | Dokumentert porsjon; pakkevekt; tvetydig label; feil enhet; manglende data; gammel heuristisk cache |
| ViewModels | Logging/redigering; måltidsendring; produktrefresh; feil/retry; raske gjentatte lagretrykk |
| Lokal lagring | Omstart; gammel JSON; historisk snapshot; atomisk rollback; køpayload; kopiering/angre/eksport |
| Synk/backend | Gamle/nye payloads; mismatch/null; duplikatlevering; retry; eierskap; SQL/RPC roundtrip; saved meal der berørt |
| UI | Polarbrød: velg porsjon → 2 → lagre → gjenåpne → endre til 3; ml-vare; vare uten porsjon; offline; stor tekst; VoiceOver |

Utvid relevante `ProductSearchTests`, `LogViewModelTests`, lagrings- og
måltidsgjenbrukstester; lag avgrensede porsjonstester der det er nytt domeneansvar.
Kjør bare berørte Swift Testing-suiter og kritiske UI-flyter med
`xcodebuild test -only-testing:…` på installert QA-simulator.
Kjør berørte Deno-kontrakttester og pgTAP/RPC-tester i lokal Supabase.
Full testpakke og releasebygg hører til en separat releasegate.

Akseptanse: antall, grunnlag, total og næring samsvarer etter lagring, omstart,
redigering og retry. Ingen feilaktig stykkvekt, tap av historikk eller IO i views.

## Leveranserekkefølge og dokumentasjon

1. Normalisert porsjonsmodell og adapter, med tester.
2. Mengdelogikk og valgfritt loggsnapshot, med lagrings-/kontrakttester.
3. Servermigrasjon og kontraktstøtte; verifiser i lokal Supabase/staging.
4. Produktkort, redigering og loggvisning kobles til samme mengdelogikk.
5. Gjenbruk, eksport, sist brukt og relevante saved-meal-flyter ferdigstilles.
6. Kritisk UI-flyt og tilgjengelighet verifiseres; arkitekturreview avslutter.

Hvert trinn skal være byggbart og testbart. Klientens nye sending aktiveres
først etter serverstøtte. Ingen produksjonsmigrasjon eller deploy inngår.

Oppdater relevante deler av brukerflyt, datamodell, synkkontrakt, prosjektstatus
og testveiledning sammen med implementasjonen. Før beslutningen om historisk
porsjonssnapshot i `docs/decisions.md` når den implementeres.

Skills brukt i arbeidet: product-review, product-design, ios-swiftui,
nutrition-privacy, offline-sync, backend-api og qa-release.
Planen følger MVVM, local-first, atomiske writes, kilde/enhet og testbarhet.
Ingen arkitekturavvik er introdusert. Implementasjonen bevarer View → ViewModel
→ Repository → LocalStore/API, atomisk lokal logg/kø, tokenbasert eierskap og
historisk kilde/enhet.

## Verifisering 2026-10-02

- 77 målrettede Swift-tester i de syv berørte suitene var grønne før pausen.
- UI-flyten med to brød → omstart → tre brød er grønn på isolert iPhone 17-simulator,
  inkludert redigering ved største tilgjengelighetstekst. Testen kontrollerer samme
  logg-ID etter lagring. Eksisterende UI-test for logging/redigering på tidligere dag er også grønn.
- 69 pgTAP-tester i separat lokal Supabase er grønne; SQL-lint fant ingen skjemafeil.
- 10 Deno-kontrakttester, typekontroll av kontrakt/Edge Function og lint er grønne.
- `git diff --check` er grønn. Full testpakke og releasebygg er ikke kjørt.

Automatiserte tester dekker ml, manglende porsjon, lokal rollback/retry,
historisk snapshot, eksport og gjenbruk. Manuell VoiceOver-kontroll og fysisk
iPhone gjenstår før release. Ingen produksjonsdeploy er utført; synk forblir
deaktivert til serverstøtte og releasegate er godkjent.
