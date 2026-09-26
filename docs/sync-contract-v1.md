# Synkkontrakt v1

Dato: 2026-09-15
Status: implementert bak `backendSyncEnabled = false`

Klienten sender `POST /v1/sync/events` med Bearer-token og:

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
`saved_meal.upsert` og `saved_meal.delete`.
Backend godtar midlertidig de eldre aliasene `log.create`, `log.update` og
`weight.add` for bakoverkompatibilitet.

Lokal domeneskriving og innsetting i `sync_queue` skjer i samme SQLite-
transaksjon. Backend registrerer hendelsen og anvender domeneendringen i samme
Prisma-transaksjon. `eventId` er global idempotensnøkkel. Replay bekreftes bare
når inbox-raden eies av samme innloggede bruker; kryssbruker-kollisjon avvises.
Oppdatering av logger, vekt og brukeropprettede produkter krever at eksisterende
rad eies av innlogget bruker.

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

Produksjonsflagget skal ikke aktiveres før integrasjonstest mot PostgreSQL og en
full iOS testkjøring er grønn.

`saved_meal.upsert` bærer hele aggregatet med ID, navn, valgfri foreslått
måltidskategori, `updatedAt` og 1–50 elementer. Hvert element har stabil ID,
produktreferanse og navn, mengde med `amountUnit` (`g` eller `ml`), lagret
kcal/makrogrunnlag, ernæringskilde og rekkefølge. Det historiske feltet
`amountG` bærer den numeriske mengden; manglende enhet tolkes som `g`. Backend
henter eier fra tokenet og erstatter måltidets elementer i
samme transaksjon som inbox-raden. `saved_meal.delete` inneholder måltids-ID.

Kontrakten er fortsatt en opplastingskontrakt. Nedlasting og konfliktløsning
mellom flere enheter er ikke implementert.
