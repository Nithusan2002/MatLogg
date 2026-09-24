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

Produksjonsflagget skal ikke aktiveres før integrasjonstest mot PostgreSQL og en
full iOS testkjøring er grønn.

`saved_meal.upsert` bærer hele aggregatet med ID, navn, valgfri foreslått
måltidskategori, `updatedAt` og 1–50 elementer. Hvert element har stabil ID,
produktreferanse og navn, gram, lagret kcal/makrogrunnlag, ernæringskilde og
rekkefølge. Backend henter eier fra tokenet og erstatter måltidets elementer i
samme transaksjon som inbox-raden. `saved_meal.delete` inneholder måltids-ID.

Kontrakten er fortsatt en opplastingskontrakt. Nedlasting og konfliktløsning
mellom flere enheter er ikke implementert.
