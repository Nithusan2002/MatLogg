# Synkkontrakt v1

Dato: 2026-09-15
Status: implementert bak `backendSyncEnabled = false`

Klienten sender `<SUPABASE_URL>/functions/v1/sync-events` med Supabase
Bearer-token og:

```json
{
  "deviceId": "uuid",
  "clientTime": "ISO-8601",
  "events": [{
    "eventId": "uuid",
    "type": "log.upsert",
    "createdAt": "ISO-8601",
    "entityId": "uuid eller null",
    "schemaVersion": 1,
    "payload": "base64(JSON)"
  }]
}
```

Maks 50 hendelser per batch og 64 KiB dekodet payload per hendelse. `payload`
må være kanonisk, polstret base64, og `entityId` må være UUID eller `null`.

Canonical typer er `log.upsert`, `log.delete`, `goal.set`, `favorite.add`,
`favorite.remove`, `weight.upsert`, `weight.delete`, `product.upsert`,
`saved_meal.upsert`, `saved_meal.delete`, `water.upsert` og `water.delete`.
Backend godtar midlertidig de eldre aliasene `log.create`, `log.update` og
`weight.add` for bakoverkompatibilitet.

Lokal domeneskriving og innsetting i `sync_queue` skjer i samme SQLite-
transaksjon. Supabase-RPC-en registrerer hendelsen og anvender domeneendringen i
samme PostgreSQL-transaksjon. `eventId` er global idempotensnøkkel. Replay bekreftes bare
når inbox-raden eies av samme innloggede bruker; kryssbruker-kollisjon avvises.
Oppdatering av logger, vekt og brukeropprettede produkter krever at eksisterende
rad eies av innlogget bruker.

Hver lokal køhendelse har i tillegg `ownerUserId`, som brukes til å velge bare
hendelser for den aktive autentiserte brukeren. Feltet er lokal rutingmetadata
og inngår ikke i wire-formatet; backend fortsetter å hente identitet fra tokenet.
Eldre, ikke-ferdige hendelser uten sikker eierbinding settes i `quarantined` og
kan ikke sendes eller gjøres retrybare manuelt.

`product.upsert` er for produkter brukeren selv oppretter eller korrigerer.
Produkter hentet fra eksterne kataloger som Open Food Facts og Matvaretabellen
lagres som lokal cache og skal ikke opprette synkhendelser. De får stabil lokal
identitet fra `kilde + ekstern ID`, slik at de kan gjenbrukes uten å gjøre
tredjeparts katalogdata til brukereid domenedata. Dette endrer ikke wire-format
eller schema-versjon.

`log.upsert` har en additiv, bakoverkompatibel `unit` med verdiene `g` eller
`ml`. Feltet som historisk heter `grams` bærer den numeriske mengden i oppgitt
enhet; navnet beholdes i v1 for wire-kompatibilitet. Manglende `unit` tolkes som
`g`. Nye klienter og backend bevarer enheten, og backend må rulles ut før en
klient som sender `ml` dersom produksjonssynk senere aktiveres.

`kcal` i `log.upsert` og `calories` i elementene til `saved_meal.upsert` er
ikke-negative desimaltall. Klient og backend bevarer beregnet presisjon gjennom
lagring og synk; avrunding til hele kcal skjer bare ved visning. Heltall fra
eldre klienter er fortsatt gyldige tall i samme v1-format. Backend med støtte
for desimallagring må rulles ut før en klient som sender desimale
`saved_meal.upsert`-verdier.

Produksjonsflagget skal ikke aktiveres før integrasjonstest mot PostgreSQL og en
full iOS testkjøring er grønn.

`saved_meal.upsert` bærer hele aggregatet med ID, navn, valgfri foreslått
måltidskategori, `updatedAt` og 1–50 elementer. Hvert element har stabil ID,
produktreferanse og navn, mengde med `amountUnit` (`g` eller `ml`), lagret
kcal/makrogrunnlag, ernæringskilde og rekkefølge. Det historiske feltet
`amountG` bærer den numeriske mengden; manglende enhet tolkes som `g`. Backend
henter eier fra tokenet og erstatter måltidets elementer i
samme transaksjon som inbox-raden. `saved_meal.delete` inneholder måltids-ID.
Valgfri `localImageData` er kun lokal og inngår ikke i synkpayloaden.

Kontrakten er fortsatt en opplastingskontrakt. Nedlasting og konfliktløsning
mellom flere enheter er ikke implementert. Gjeldende produktadferd, betydningen
av en tom enhetskø og krav før toveis synk beskrives i
[offline-adferd og synkstatus](offline-behavior.md).

`water.upsert` (additiv v1-type) inneholder `id`, `date` og `createdAt` som
UUID / ISO-8601. Hver rad er ett glass, uten estimert volum. `water.delete`
inneholder `id`. Eier hentes fra tokenet, og inbox og glass skrives atomisk.
Servermigrasjon og Edge Function må oppdateres før klienten sender vannevents.
Eldre servere avviser den nye typen; aktiver derfor ikke synk før utrulling og
kontrakt-/integrasjonstester er godkjent. Opplasting gir ingen toveis synk.

## Produktets næringsgrunnlag (2026-10-03)

`product.upsert` har additive valgfrie `nutritionBasis` (per100g/per100ml),
`servings` og `manualNutritionInput` (basis, amount, unit, label og rå kcal/makroer).
Historisk `nutrientsPer100g` inneholder per-100-verdier i eksplisitt grunnlag;
fravær av grunnlag betyr per100g for eldre klienter. Serveren lagrer metadata
atomisk med produkt og inbox. Migrasjonen 20261003090000 og Edge-valideringen
må rulles ut før klienten; schemaVersion forblir 1. Produksjonssynk forblir av
inntil database- og integrasjonstester er verifisert.
