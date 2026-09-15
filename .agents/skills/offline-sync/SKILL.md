---
name: offline-sync
description: Utform og endre MatLoggs lokale lagring, synkkø, event-format, retry, idempotens og konfliktregler mellom iOS og backend.
---

# Offline-first og synk

Les `docs/specs/05-data-model-sync.md`, `docs/specs/07-edge-cases.md`, `LocalStore.swift`, `SyncEngine.swift`, `APIService.swift` og backendens sync-modul.

Lokale brukerhandlinger skal lagres atomisk før nettverksforsøk. Hver hendelse skal ha stabil unik ID, eksplisitt type og schema-versjon. Retry må være trygg: backend skal deduplisere på event-ID, og klienten skal ikke miste en hendelse ved timeout eller prosessavbrudd.

Ved kontraktsendringer, vurder bakoverkompatibilitet, utrullekkefølge, ukjent event-type, delvis batch-feil, payload-grenser, klokkeavvik og to enheter. Ikke endre konfliktstrategi implisitt.

Test minst den berørte happy pathen og relevante feilmoduser: gjentatt levering, offline→online, avbrutt in-flight, valideringsfeil og retry/backoff. Oppdater både dokumentert format og begge sider av kontrakten når de påvirkes.
