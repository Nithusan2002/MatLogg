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

Maks 50 hendelser per batch og 64 KiB dekodet payload per hendelse.

Canonical typer er `log.upsert`, `log.delete`, `goal.set`, `favorite.add`,
`favorite.remove`, `weight.upsert`, `weight.delete` og `product.upsert`.
Backend godtar midlertidig de eldre aliasene `log.create`, `log.update` og
`weight.add` for bakoverkompatibilitet.

Lokal domeneskriving og innsetting i `sync_queue` skjer i samme SQLite-
transaksjon. Backend registrerer hendelsen og anvender domeneendringen i samme
Prisma-transaksjon. `eventId` er idempotensnøkkel. Oppdatering av logger, vekt og
brukeropprettede produkter krever at eksisterende rad eies av innlogget bruker.

Produksjonsflagget skal ikke aktiveres før integrasjonstest mot PostgreSQL og en
full iOS testkjøring er grønn.
